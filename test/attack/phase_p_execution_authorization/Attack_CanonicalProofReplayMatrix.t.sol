// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {AkmenaCore} from "../../../src/core/AkmenaCore.sol";

import {AkmenaPolicyBoundary} from "../../../src/authorization/AkmenaPolicyBoundary.sol";

import {AkmenaExecutionAuthorization} from "../../../src/authorization/AkmenaExecutionAuthorization.sol";

contract CanonicalProofReplayTarget {
    uint256 public executions;
    address public lastCaller;
    uint256 public lastAmount;

    function execute(uint256 amount) external returns (bool) {
        executions += 1;
        lastCaller = msg.sender;
        lastAmount = amount;

        return true;
    }

    function alternate(uint256 amount) external returns (bool) {
        executions += 1;
        lastCaller = msg.sender;
        lastAmount = amount;

        return true;
    }
}

contract CanonicalProofReplayModule {
    mapping(uint256 => bool) internal validProofs;

    function setProof(uint256 proofId) external {
        validProofs[proofId] = true;
    }

    function consumeProof(uint256 proofId) external returns (bool) {
        if (!validProofs[proofId]) {
            return false;
        }

        validProofs[proofId] = false;
        return true;
    }
}

contract AttackCanonicalProofReplayMatrixTest is Test {
    AkmenaCore internal core;
    AkmenaPolicyBoundary internal boundary;
    AkmenaExecutionAuthorization internal authorization;

    CanonicalProofReplayTarget internal target;
    CanonicalProofReplayModule internal proofModule;

    uint256 internal constant AGENT_KEY = 0xA11CE;

    address internal agent;
    address internal operator = address(0x1111);

    address internal recipient = address(0xBBBB);

    bytes32 internal constant PROOF_MODULE_KEY = keccak256("AKMENA.CANONICAL.PROOF");

    uint256 internal constant PROOF_ID = 9001;

    function setUp() public {
        core = new AkmenaCore();

        boundary = new AkmenaPolicyBoundary(address(core));

        authorization = boundary.executionAuthorization();

        target = new CanonicalProofReplayTarget();

        proofModule = new CanonicalProofReplayModule();

        agent = vm.addr(AGENT_KEY);

        vm.prank(operator);

        boundary.setAgentPolicy(agent, 20 ether, 20 ether, false);

        // AkmenaCore.registerModule() is restricted to the
        // Core deployer. `core` was deployed by this test
        // contract, so this call must originate from this
        // test contract rather than the policy operator.
        core.registerModule(PROOF_MODULE_KEY, address(proofModule), "1.0.0");

        proofModule.setProof(PROOF_ID);
    }

    function _intent(address target_, bytes4 selector_, bytes memory payload_, uint256 amount_, uint256 nonce_)
        internal
        view
        returns (AkmenaExecutionAuthorization.ExecutionIntent memory)
    {
        return AkmenaExecutionAuthorization.ExecutionIntent({
            operator: operator,
            agent: agent,
            target: target_,
            selector: selector_,
            asset: address(0),
            calldataHash: keccak256(payload_),
            amount: amount_,
            value: 0,
            proofModuleKey: PROOF_MODULE_KEY,
            proofId: PROOF_ID,
            nonce: nonce_,
            validAfter: block.timestamp,
            deadline: block.timestamp + 1 hours
        });
    }

    function _sign(AkmenaExecutionAuthorization.ExecutionIntent memory intent) internal view returns (bytes memory) {
        bytes32 digest = authorization.hashIntent(intent);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(AGENT_KEY, digest);

        return abi.encodePacked(r, s, v);
    }

    function test_ExactCanonicalProofExecutionSucceeds() public {
        uint256 amount = 1 ether;

        bytes memory payload = abi.encodeWithSelector(target.execute.selector, amount);

        AkmenaExecutionAuthorization.ExecutionIntent memory intent =
            _intent(address(target), target.execute.selector, payload, amount, 0);

        bytes memory signature = _sign(intent);

        vm.prank(agent);

        boundary.executeAuthorizedAgentCall(intent, payload, signature);

        assertEq(target.executions(), 1);

        assertEq(target.lastAmount(), amount);
    }

    function test_ProofCannotBeReusedAfterSuccessfulExecution() public {
        uint256 amount = 1 ether;

        bytes memory payload = abi.encodeWithSelector(target.execute.selector, amount);

        AkmenaExecutionAuthorization.ExecutionIntent memory intent =
            _intent(address(target), target.execute.selector, payload, amount, 0);

        bytes memory signature = _sign(intent);

        vm.prank(agent);

        boundary.executeAuthorizedAgentCall(intent, payload, signature);

        assertEq(target.executions(), 1);

        vm.prank(agent);

        vm.expectRevert();

        boundary.executeAuthorizedAgentCall(intent, payload, signature);

        assertEq(target.executions(), 1);
    }

    function test_SameProofCannotAuthorizeDifferentTarget() public {
        CanonicalProofReplayTarget secondTarget = new CanonicalProofReplayTarget();

        uint256 amount = 1 ether;

        bytes memory originalPayload = abi.encodeWithSelector(target.execute.selector, amount);

        AkmenaExecutionAuthorization.ExecutionIntent memory original =
            _intent(address(target), target.execute.selector, originalPayload, amount, 0);

        bytes memory signature = _sign(original);

        bytes memory substitutedPayload = abi.encodeWithSelector(secondTarget.execute.selector, amount);

        AkmenaExecutionAuthorization.ExecutionIntent memory substituted =
            _intent(address(secondTarget), secondTarget.execute.selector, substitutedPayload, amount, 0);

        // Signature belongs to `original`, not `substituted`.
        vm.prank(agent);

        vm.expectRevert();

        boundary.executeAuthorizedAgentCall(substituted, substitutedPayload, signature);

        assertEq(secondTarget.executions(), 0);
    }

    function test_SameProofCannotAuthorizeDifferentSelector() public {
        uint256 amount = 1 ether;

        bytes memory originalPayload = abi.encodeWithSelector(target.execute.selector, amount);

        AkmenaExecutionAuthorization.ExecutionIntent memory original =
            _intent(address(target), target.execute.selector, originalPayload, amount, 0);

        bytes memory signature = _sign(original);

        bytes memory substitutedPayload = abi.encodeWithSelector(target.alternate.selector, amount);

        AkmenaExecutionAuthorization.ExecutionIntent memory substituted =
            _intent(address(target), target.alternate.selector, substitutedPayload, amount, 0);

        vm.prank(agent);

        vm.expectRevert();

        boundary.executeAuthorizedAgentCall(substituted, substitutedPayload, signature);

        assertEq(target.executions(), 0);
    }

    function test_SameProofCannotAuthorizeDifferentCalldata() public {
        uint256 signedAmount = 1 ether;

        uint256 substitutedAmount = 2 ether;

        bytes memory originalPayload = abi.encodeWithSelector(target.execute.selector, signedAmount);

        AkmenaExecutionAuthorization.ExecutionIntent memory original =
            _intent(address(target), target.execute.selector, originalPayload, signedAmount, 0);

        bytes memory signature = _sign(original);

        bytes memory substitutedPayload = abi.encodeWithSelector(target.execute.selector, substitutedAmount);

        AkmenaExecutionAuthorization.ExecutionIntent memory substituted =
            _intent(address(target), target.execute.selector, substitutedPayload, substitutedAmount, 0);

        vm.prank(agent);

        vm.expectRevert();

        boundary.executeAuthorizedAgentCall(substituted, substitutedPayload, signature);

        assertEq(target.executions(), 0);
    }

    function test_SameProofCannotAuthorizeDifferentAmount() public {
        uint256 signedAmount = 1 ether;

        uint256 substitutedAmount = 2 ether;

        bytes memory payload = abi.encodeWithSelector(target.execute.selector, signedAmount);

        AkmenaExecutionAuthorization.ExecutionIntent memory original =
            _intent(address(target), target.execute.selector, payload, signedAmount, 0);

        bytes memory signature = _sign(original);

        AkmenaExecutionAuthorization.ExecutionIntent memory substituted =
            _intent(address(target), target.execute.selector, payload, substitutedAmount, 0);

        vm.prank(agent);

        vm.expectRevert();

        boundary.executeAuthorizedAgentCall(substituted, payload, signature);

        assertEq(target.executions(), 0);
    }

    function test_SameProofCannotAuthorizeDifferentOperator() public {
        address alternateOperator = address(0x2222);

        uint256 amount = 1 ether;

        bytes memory payload = abi.encodeWithSelector(target.execute.selector, amount);

        AkmenaExecutionAuthorization.ExecutionIntent memory original =
            _intent(address(target), target.execute.selector, payload, amount, 0);

        bytes memory signature = _sign(original);

        AkmenaExecutionAuthorization.ExecutionIntent memory substituted = AkmenaExecutionAuthorization.ExecutionIntent({
            operator: alternateOperator,
            agent: agent,
            target: address(target),
            selector: target.execute.selector,
            asset: address(0),
            calldataHash: keccak256(payload),
            amount: amount,
            value: 0,
            proofModuleKey: PROOF_MODULE_KEY,
            proofId: PROOF_ID,
            nonce: 0,
            validAfter: block.timestamp,
            deadline: block.timestamp + 1 hours
        });

        vm.prank(agent);

        vm.expectRevert();

        boundary.executeAuthorizedAgentCall(substituted, payload, signature);

        assertEq(target.executions(), 0);
    }

    function test_SameProofCannotAuthorizeDifferentAgent() public {
        uint256 alternateAgentKey = 0xCAFE;

        address alternateAgent = vm.addr(alternateAgentKey);

        uint256 amount = 1 ether;

        bytes memory payload = abi.encodeWithSelector(target.execute.selector, amount);

        AkmenaExecutionAuthorization.ExecutionIntent memory original =
            _intent(address(target), target.execute.selector, payload, amount, 0);

        bytes memory signature = _sign(original);

        AkmenaExecutionAuthorization.ExecutionIntent memory substituted = AkmenaExecutionAuthorization.ExecutionIntent({
            operator: operator,
            agent: alternateAgent,
            target: address(target),
            selector: target.execute.selector,
            asset: address(0),
            calldataHash: keccak256(payload),
            amount: amount,
            value: 0,
            proofModuleKey: PROOF_MODULE_KEY,
            proofId: PROOF_ID,
            nonce: 0,
            validAfter: block.timestamp,
            deadline: block.timestamp + 1 hours
        });

        vm.prank(alternateAgent);

        vm.expectRevert();

        boundary.executeAuthorizedAgentCall(substituted, payload, signature);

        assertEq(target.executions(), 0);
    }

    function test_SameProofCannotAuthorizeDifferentNonce() public {
        uint256 amount = 1 ether;

        bytes memory payload = abi.encodeWithSelector(target.execute.selector, amount);

        AkmenaExecutionAuthorization.ExecutionIntent memory original =
            _intent(address(target), target.execute.selector, payload, amount, 0);

        bytes memory signature = _sign(original);

        AkmenaExecutionAuthorization.ExecutionIntent memory substituted =
            _intent(address(target), target.execute.selector, payload, amount, 1);

        vm.prank(agent);

        vm.expectRevert();

        boundary.executeAuthorizedAgentCall(substituted, payload, signature);

        assertEq(target.executions(), 0);
    }
}
