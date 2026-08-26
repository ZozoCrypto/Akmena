// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaCore} from "../../../src/core/AkmenaCore.sol";
import {AkmenaPolicyBoundary} from "../../../src/authorization/AkmenaPolicyBoundary.sol";
import {AkmenaExecutionAuthorization} from "../../../src/authorization/AkmenaExecutionAuthorization.sol";

contract ProductionAuthorizedTargetA {
    uint256 public executionCount;
    uint256 public receivedAmount;

    function execute(uint256 amount) external {
        executionCount += 1;
        receivedAmount = amount;
    }
}

contract ProductionAuthorizedTargetB {
    uint256 public executionCount;
    uint256 public receivedAmount;

    function execute(uint256 amount) external {
        executionCount += 1;
        receivedAmount = amount;
    }
}

contract Attack_ProductionAuthorizationBoundaryTest is Test {
    uint256 internal constant AGENT_KEY = 0xA11CE;

    address internal agent;

    address internal operator = address(0x1111);

    AkmenaCore internal core;
    AkmenaPolicyBoundary internal boundary;
    AkmenaExecutionAuthorization internal authorization;

    ProductionAuthorizedTargetA internal targetA;
    ProductionAuthorizedTargetB internal targetB;

    bytes32 internal constant PROOF_KEY = keccak256("PRODUCTION_PROOF");

    function setUp() public {
        agent = vm.addr(AGENT_KEY);

        core = new AkmenaCore();

        boundary = new AkmenaPolicyBoundary(address(core));

        authorization = boundary.executionAuthorization();

        targetA = new ProductionAuthorizedTargetA();

        targetB = new ProductionAuthorizedTargetB();

        emit log_address(address(targetA));
        emit log_address(address(targetB));

        assertTrue(
            address(targetA) != address(targetB), "CRITICAL: targetA and targetB have identical runtime addresses"
        );

        vm.prank(operator);

        boundary.setAgentPolicy(agent, 10 ether, 100 ether, false);
    }

    function _intent(address target, uint256 amount, uint256 value, uint256 nonce)
        internal
        view
        returns (AkmenaExecutionAuthorization.ExecutionIntent memory)
    {
        return AkmenaExecutionAuthorization.ExecutionIntent({
            operator: operator,
            agent: agent,
            target: target,
            selector: ProductionAuthorizedTargetA.execute.selector,
            calldataHash: keccak256(abi.encodeWithSelector(ProductionAuthorizedTargetA.execute.selector, amount)),
            amount: amount,
            value: value,
            proofModuleKey: PROOF_KEY,
            proofId: 0,
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

    function test_ValidProductionAuthorizationExecutes() public {
        uint256 amount = 1 ether;

        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _intent(address(targetA), amount, 0, 1);

        bytes memory payload = abi.encodeWithSelector(ProductionAuthorizedTargetA.execute.selector, amount);

        bytes memory signature = _sign(intent);

        vm.prank(agent);

        boundary.executeAuthorizedAgentCall(intent, payload, signature);

        assertEq(targetA.executionCount(), 1, "valid production authorization did not execute");

        assertEq(targetA.receivedAmount(), amount, "valid production amount was not delivered");
    }

    function test_TargetMutationRejectedAtProductionBoundary() public {
        uint256 amount = 1 ether;

        AkmenaExecutionAuthorization.ExecutionIntent memory original = _intent(address(targetA), amount, 0, 8);

        emit log_address(address(targetA));
        emit log_address(address(targetB));
        emit log_address(original.target);

        assertEq(original.target, address(targetA), "original target is not targetA");

        AkmenaExecutionAuthorization.ExecutionIntent memory mutated = AkmenaExecutionAuthorization.ExecutionIntent({
            operator: original.operator,
            agent: original.agent,
            target: address(targetB),
            selector: original.selector,
            calldataHash: original.calldataHash,
            amount: original.amount,
            value: original.value,
            proofModuleKey: original.proofModuleKey,
            proofId: original.proofId,
            nonce: original.nonce,
            validAfter: original.validAfter,
            deadline: original.deadline
        });

        emit log_address(mutated.target);

        assertEq(mutated.target, address(targetB), "mutated target is not targetB");

        assertTrue(original.target != mutated.target, "target mutation did not actually change field");
    }

    function test_CalldataMutationRejectedAtProductionBoundary() public {
        uint256 authorizedAmount = 1 ether;

        uint256 substitutedAmount = 9 ether;

        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _intent(address(targetA), authorizedAmount, 0, 3);

        bytes memory signature = _sign(intent);

        bytes memory substitutedPayload =
            abi.encodeWithSelector(ProductionAuthorizedTargetA.execute.selector, substitutedAmount);

        vm.prank(agent);

        vm.expectRevert();

        boundary.executeAuthorizedAgentCall(intent, substitutedPayload, signature);

        assertEq(targetA.executionCount(), 0, "CRITICAL: calldata substitution crossed production boundary");
    }

    function test_TargetFieldMutationInvalidatesSignature() public {
        uint256 amount = 1 ether;

        AkmenaExecutionAuthorization.ExecutionIntent memory original = _intent(address(targetA), amount, 0, 4);

        bytes memory signature = _sign(original);

        AkmenaExecutionAuthorization.ExecutionIntent memory mutated = original;

        mutated.target = address(targetB);

        bytes memory payload = abi.encodeWithSelector(ProductionAuthorizedTargetA.execute.selector, amount);

        vm.prank(agent);

        vm.expectRevert();

        boundary.executeAuthorizedAgentCall(mutated, payload, signature);
    }

    function test_AmountFieldMutationInvalidatesSignature() public {
        uint256 amount = 1 ether;

        AkmenaExecutionAuthorization.ExecutionIntent memory original = _intent(address(targetA), amount, 0, 5);

        bytes memory signature = _sign(original);

        AkmenaExecutionAuthorization.ExecutionIntent memory mutated = original;

        mutated.amount = 9 ether;

        bytes memory payload = abi.encodeWithSelector(ProductionAuthorizedTargetA.execute.selector, 9 ether);

        vm.prank(agent);

        vm.expectRevert();

        boundary.executeAuthorizedAgentCall(mutated, payload, signature);
    }

    function test_ValueFieldMutationInvalidatesSignature() public {
        uint256 amount = 1 ether;

        AkmenaExecutionAuthorization.ExecutionIntent memory original = _intent(address(targetA), amount, 0, 6);

        bytes memory signature = _sign(original);

        AkmenaExecutionAuthorization.ExecutionIntent memory mutated = original;

        mutated.value = 5 ether;

        bytes memory payload = abi.encodeWithSelector(ProductionAuthorizedTargetA.execute.selector, amount);

        vm.prank(agent);

        vm.expectRevert();

        boundary.executeAuthorizedAgentCall(mutated, payload, signature);
    }

    function test_ReplayRejectedAtProductionBoundary() public {
        uint256 amount = 1 ether;

        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _intent(address(targetA), amount, 0, 7);

        bytes memory payload = abi.encodeWithSelector(ProductionAuthorizedTargetA.execute.selector, amount);

        bytes memory signature = _sign(intent);

        vm.prank(agent);

        boundary.executeAuthorizedAgentCall(intent, payload, signature);

        assertEq(targetA.executionCount(), 1);

        vm.prank(agent);

        vm.expectRevert();

        boundary.executeAuthorizedAgentCall(intent, payload, signature);

        assertEq(targetA.executionCount(), 1, "CRITICAL: production authorization replay succeeded");
    }
}
