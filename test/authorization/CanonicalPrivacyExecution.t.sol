// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaCore} from "../../src/core/AkmenaCore.sol";
import {AkmenaPolicyBoundary} from "../../src/authorization/AkmenaPolicyBoundary.sol";
import {AkmenaExecutionAuthorization} from "../../src/authorization/AkmenaExecutionAuthorization.sol";
import {PrivacyEngine} from "../../src/privacy/PrivacyEngine.sol";

contract CanonicalPrivacyTarget {
    uint256 public calls;
    uint256 public lastAmount;

    function execute(uint256 amount) external {
        calls += 1;
        lastAmount = amount;
    }
}

contract CanonicalPrivacyExecutionTest is Test {
    uint256 internal constant AGENT_KEY = 0xA11CE;

    address internal agent;
    address internal operator = address(0x1111);

    bytes32 internal constant PRIVACY_KEY =
        keccak256("PRIVACY_ENGINE");

    AkmenaCore internal core;
    AkmenaPolicyBoundary internal boundary;
    AkmenaExecutionAuthorization internal authorization;
    PrivacyEngine internal privacy;
    CanonicalPrivacyTarget internal target;

    function setUp() public {
        agent = vm.addr(AGENT_KEY);

        core = new AkmenaCore();
        boundary = new AkmenaPolicyBoundary(address(core));
        authorization = boundary.executionAuthorization();

        privacy = new PrivacyEngine();
        target = new CanonicalPrivacyTarget();

        core.registerModule(
            PRIVACY_KEY,
            address(privacy),
            "1.0.0"
        );

        vm.prank(operator);
        boundary.setAgentPolicy(
            agent,
            10 ether,
            100 ether,
            true
        );
    }

    function _sign(
        AkmenaExecutionAuthorization.ExecutionIntent memory intent
    ) internal view returns (bytes memory) {
        bytes32 digest = authorization.hashIntent(intent);

        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(AGENT_KEY, digest);

        return abi.encodePacked(r, s, v);
    }

    function _buildIntent(
        bytes32 nullifierHash,
        bytes memory payload,
        uint256 amount,
        uint256 nonce
    )
        internal
        view
        returns (
            AkmenaExecutionAuthorization.ExecutionIntent memory
        )
    {
        bytes4 selector =
            CanonicalPrivacyTarget.execute.selector;

        return AkmenaExecutionAuthorization.ExecutionIntent({
            operator: operator,
            agent: agent,
            target: address(target),
            selector: selector,
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

    function _createPrivacyProof(
        bytes32 nullifierHash,
        bytes32 secret,
        uint256 amount
    ) internal {
        bytes32 commitment =
            keccak256(
                abi.encodePacked(
                    nullifierHash,
                    secret,
                    amount,
                    payable(agent)
                )
            );

        vm.deal(agent, amount);

        vm.prank(agent);
        privacy.depositPrivateEscrow{value: amount}(
            commitment
        );

        // The current PrivacyEngine proof subject is the recipient.
        vm.prank(agent);
        privacy.executePrivateSettlement(
            nullifierHash,
            secret,
            amount,
            payable(agent)
        );
    }

    function test_CanonicalPrivacyProofAuthorizesExactExecution()
        public
    {
        bytes32 nullifierHash =
            keccak256("canonical-privacy");

        bytes32 secret =
            keccak256("canonical-privacy-secret");

        uint256 amount = 1 ether;

        _createPrivacyProof(
            nullifierHash,
            secret,
            amount
        );

        bytes memory payload =
            abi.encodeWithSelector(
                CanonicalPrivacyTarget.execute.selector,
                amount
            );

        AkmenaExecutionAuthorization.ExecutionIntent memory intent =
            _buildIntent(
                nullifierHash,
                payload,
                amount,
                1
            );

        bytes memory signature =
            _sign(intent);

        vm.prank(agent);

        boundary.executeAuthorizedAgentCall(
            intent,
            payload,
            signature
        );

        assertEq(target.calls(), 1);
        assertEq(target.lastAmount(), amount);
    }

    function test_CanonicalPrivacyProofCannotChangeProofModule()
        public
    {
        bytes32 nullifierHash =
            keccak256("canonical-privacy-module");

        bytes32 secret =
            keccak256("canonical-privacy-module-secret");

        uint256 amount = 1 ether;

        _createPrivacyProof(
            nullifierHash,
            secret,
            amount
        );

        bytes memory payload =
            abi.encodeWithSelector(
                CanonicalPrivacyTarget.execute.selector,
                amount
            );

        AkmenaExecutionAuthorization.ExecutionIntent memory original =
            _buildIntent(
                nullifierHash,
                payload,
                amount,
                2
            );

        bytes memory signature =
            _sign(original);

        AkmenaExecutionAuthorization.ExecutionIntent memory mutated =
            original;

        mutated.proofModuleKey =
            keccak256("ESCROW_ENGINE");

        vm.prank(agent);

        vm.expectRevert();

        boundary.executeAuthorizedAgentCall(
            mutated,
            payload,
            signature
        );

        assertEq(target.calls(), 0);
    }

    function test_CanonicalPrivacyProofCannotChangeProofId()
        public
    {
        bytes32 nullifierHash =
            keccak256("canonical-privacy-proof-id");

        bytes32 secret =
            keccak256("canonical-privacy-proof-id-secret");

        uint256 amount = 1 ether;

        _createPrivacyProof(
            nullifierHash,
            secret,
            amount
        );

        bytes memory payload =
            abi.encodeWithSelector(
                CanonicalPrivacyTarget.execute.selector,
                amount
            );

        AkmenaExecutionAuthorization.ExecutionIntent memory original =
            _buildIntent(
                nullifierHash,
                payload,
                amount,
                3
            );

        bytes memory signature =
            _sign(original);

        AkmenaExecutionAuthorization.ExecutionIntent memory mutated =
            original;

        mutated.proofId =
            uint256(nullifierHash) + 1;

        vm.prank(agent);

        vm.expectRevert();

        boundary.executeAuthorizedAgentCall(
            mutated,
            payload,
            signature
        );

        assertEq(target.calls(), 0);
    }
}
