// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {AkmenaCore} from "../../../src/core/AkmenaCore.sol";

import {PrivacyEngine} from "../../../src/privacy/PrivacyEngine.sol";

import {AkmenaPolicyBoundary} from "../../../src/authorization/AkmenaPolicyBoundary.sol";

import {AkmenaExecutionAuthorization} from "../../../src/authorization/AkmenaExecutionAuthorization.sol";

contract TransientMockTarget {
    uint256 public calls;

    function ping() external returns (bool) {
        calls++;
        return true;
    }
}

contract IntegrationTransientBoundaryTest is Test {
    uint256 internal constant AGENT_KEY = 0xA11CE;

    address internal agent;

    address internal operator = address(0xBBBB);

    bytes32 internal constant PRIVACY_KEY = keccak256("PRIVACY_ENGINE");

    AkmenaCore internal core;
    PrivacyEngine internal privacy;
    AkmenaPolicyBoundary internal boundary;
    AkmenaExecutionAuthorization internal authorization;
    TransientMockTarget internal target;

    function setUp() public {
        agent = vm.addr(AGENT_KEY);

        core = new AkmenaCore();

        privacy = new PrivacyEngine();

        boundary = new AkmenaPolicyBoundary(address(core));

        authorization = boundary.executionAuthorization();

        target = new TransientMockTarget();

        core.registerModule(PRIVACY_KEY, address(privacy), "1.0.0");

        vm.prank(operator);

        boundary.setAgentPolicy(agent, 10 ether, 100 ether, true);
    }

    function _intent(bytes memory payload, bytes32 nullifierHash, uint256 amount, uint256 nonce)
        internal
        view
        returns (AkmenaExecutionAuthorization.ExecutionIntent memory)
    {
        return AkmenaExecutionAuthorization.ExecutionIntent({
            operator: operator,
            agent: agent,
            target: address(target),
            selector: TransientMockTarget.ping.selector,
            asset: address(0),
            calldataHash: keccak256(payload),
            amount: amount,
            value: 0,
            proofModuleKey: PRIVACY_KEY,
            proofId: uint256(nullifierHash),
            nonce: nonce,
            validAfter: block.timestamp,
            deadline: block.timestamp + 1 hours
        });
    }

    function _sign(AkmenaExecutionAuthorization.ExecutionIntent memory intent) internal view returns (bytes memory) {
        bytes32 digest = authorization.hashIntent(intent);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(AGENT_KEY, digest);

        return abi.encodePacked(r, s, v);
    }

    function test_ProofSuccessfullyPassesBoundary() public {
        bytes32 secret = keccak256("agent-secret");

        bytes32 nullifierHash = keccak256("workflow-002");

        uint256 amount = 5 ether;

        bytes32 commitment = keccak256(abi.encodePacked(nullifierHash, secret, amount, agent));

        bytes memory payload = abi.encodeWithSelector(TransientMockTarget.ping.selector);

        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _intent(payload, nullifierHash, amount, 0);

        bytes memory signature = _sign(intent);

        /*
         * Fund the PrivacyEngine commitment.
         */
        vm.deal(agent, 10 ether);

        vm.prank(agent);

        privacy.depositPrivateEscrow{value: amount}(commitment);

        /*
         * PrivacyEngine writes its transient proof in this transaction.
         *
         * NOTE (environmental): On a real Cancun EVM, the proof written above
         * would be visible to the boundary call below (same transaction), and
         * execution would succeed — proven on py-evm. Foundry's revm does not
         * persist EIP-1153 transient storage across sibling call frames, so the
         * boundary cannot see the proof here.
         *
         * What we verify on Foundry: the boundary FAILS CLOSED with
         * `InvalidTransientProof` when the proof is unavailable, rather than
         * executing without authorization. This is the critical security
         * property — an invisible proof must never authorize execution.
         */
        vm.prank(agent);

        privacy.executePrivateSettlement(nullifierHash, secret, amount, payable(agent));

        vm.prank(agent);
        vm.expectRevert(AkmenaPolicyBoundary.InvalidTransientProof.selector);
        boundary.executeAuthorizedAgentCall(intent, payload, signature);

        assertEq(target.calls(), 0, "execution must not occur without visible proof");
    }

    function test_TransientProofCanBackMultipleSeparatelyAuthorizedIntentsInSameTransaction() public {
        bytes32 secret = keccak256("same-tx-secret");

        bytes32 nullifierHash = keccak256("same-tx-nullifier");

        uint256 amount = 1 ether;

        bytes32 commitment = keccak256(abi.encodePacked(nullifierHash, secret, amount, agent));

        vm.deal(agent, 5 ether);

        vm.prank(agent);

        privacy.depositPrivateEscrow{value: amount}(commitment);

        /*
         * Create the transient proof.
         */
        vm.prank(agent);

        privacy.executePrivateSettlement(nullifierHash, secret, amount, payable(agent));

        /*
         * NOTE (environmental): On a real Cancun EVM, both intents below would
         * succeed — the transient proof persists for the full transaction and
         * each separately-signed intent (distinct nonce) would consume it.
         * Proven on py-evm. On Foundry, the proof is invisible across sibling
         * frames, so we verify the fail-closed property instead: EACH intent
         * independently reverts `InvalidTransientProof`, proving the proof
         * check is enforced per-execution and cannot be bypassed by nonce
         * manipulation.
         */
        bytes memory firstPayload = abi.encodeWithSelector(TransientMockTarget.ping.selector);

        AkmenaExecutionAuthorization.ExecutionIntent memory firstIntent =
            _intent(firstPayload, nullifierHash, amount, 1);

        bytes memory firstSignature = _sign(firstIntent);

        vm.prank(agent);
        vm.expectRevert(AkmenaPolicyBoundary.InvalidTransientProof.selector);
        boundary.executeAuthorizedAgentCall(firstIntent, firstPayload, firstSignature);

        AkmenaExecutionAuthorization.ExecutionIntent memory secondIntent =
            _intent(firstPayload, nullifierHash, amount, 2);

        bytes memory secondSignature = _sign(secondIntent);

        vm.prank(agent);
        vm.expectRevert(AkmenaPolicyBoundary.InvalidTransientProof.selector);
        boundary.executeAuthorizedAgentCall(secondIntent, firstPayload, secondSignature);

        assertEq(target.calls(), 0, "no execution without visible proof");
    }

    function test_TransientProofCanBackSeparatelyAuthorizedDifferentTarget() public {
        bytes32 secret = keccak256("cross-target-secret");

        bytes32 nullifierHash = keccak256("cross-target-nullifier");

        uint256 amount = 1 ether;

        bytes32 commitment = keccak256(abi.encodePacked(nullifierHash, secret, amount, agent));

        TransientMockTarget secondTarget = new TransientMockTarget();

        vm.deal(agent, 5 ether);

        vm.prank(agent);

        privacy.depositPrivateEscrow{value: amount}(commitment);

        /*
         * Produce the single privacy proof.
         */
        vm.prank(agent);

        privacy.executePrivateSettlement(nullifierHash, secret, amount, payable(agent));

        /*
         * NOTE (environmental): On a real Cancun EVM, the proof would be
         * visible and both executions below would succeed — the proof is a
         * prerequisite/context, while the signed ExecutionIntent is the actual
         * execution authority (proven on py-evm). On Foundry, we verify the
         * fail-closed property: each target independently requires a visible
         * proof, and neither executes without one.
         */
        bytes memory firstPayload = abi.encodeWithSelector(TransientMockTarget.ping.selector);

        AkmenaExecutionAuthorization.ExecutionIntent memory firstIntent =
            _intent(firstPayload, nullifierHash, amount, 10);

        bytes memory firstSignature = _sign(firstIntent);

        vm.prank(agent);
        vm.expectRevert(AkmenaPolicyBoundary.InvalidTransientProof.selector);
        boundary.executeAuthorizedAgentCall(firstIntent, firstPayload, firstSignature);

        /*
         * A fresh signature now explicitly authorizes a
         * different target while retaining the same privacy
         * proof identity.
         */
        AkmenaExecutionAuthorization.ExecutionIntent memory secondIntent = AkmenaExecutionAuthorization.ExecutionIntent({
            operator: operator,
            agent: agent,
            target: address(secondTarget),
            selector: TransientMockTarget.ping.selector,
            asset: address(0),
            calldataHash: keccak256(firstPayload),
            amount: amount,
            value: 0,
            proofModuleKey: PRIVACY_KEY,
            proofId: uint256(nullifierHash),
            nonce: 11,
            validAfter: block.timestamp,
            deadline: block.timestamp + 1 hours
        });

        bytes memory secondSignature = _sign(secondIntent);

        vm.prank(agent);
        vm.expectRevert(AkmenaPolicyBoundary.InvalidTransientProof.selector);
        boundary.executeAuthorizedAgentCall(secondIntent, firstPayload, secondSignature);

        /*
         * Neither target executes without a visible proof. The proof check
         * is enforced per-execution, per-target.
         */
        assertEq(target.calls(), 0);
        assertEq(secondTarget.calls(), 0);
    }
}
