// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AkmenaCore} from "../../../src/core/AkmenaCore.sol";

import {Test} from "forge-std/Test.sol";
import {AkmenaPolicyBoundary} from "../../../src/authorization/AkmenaPolicyBoundary.sol";
import {AkmenaExecutionAuthorization} from "../../../src/authorization/AkmenaExecutionAuthorization.sol";

contract ExecutionSemanticsTarget {
    address public observedSender;
    uint256 public observedValue;
    bytes public observedCalldata;

    function execute(bytes calldata) external payable returns (bool) {
        observedSender = msg.sender;
        observedValue = msg.value;

        // Record the complete calldata exactly as the EVM
        // delivered it to the downstream target.
        observedCalldata = msg.data;

        return true;
    }
}

contract AttackProductionExecutionSemanticsTest is Test {
    AkmenaPolicyBoundary internal boundary;
    AkmenaCore internal core;
    ExecutionSemanticsTarget internal target;

    uint256 internal agentPk = 0xA11CE;
    address internal agent;

    address internal operator = address(0x1111);

    function setUp() public {
        agent = vm.addr(agentPk);

        core = new AkmenaCore();

        boundary = new AkmenaPolicyBoundary(address(core));

        target = new ExecutionSemanticsTarget();

        vm.deal(agent, 100 ether);

        vm.prank(operator);

        boundary.setAgentPolicy(agent, 20 ether, 20 ether, false);
    }

    function _intent(uint256 amount, uint256 value, uint256 nonce)
        internal
        view
        returns (AkmenaExecutionAuthorization.ExecutionIntent memory)
    {
        bytes memory payload = abi.encodeWithSelector(ExecutionSemanticsTarget.execute.selector, bytes("AKMENA"));

        return AkmenaExecutionAuthorization.ExecutionIntent({
            operator: operator,
            agent: agent,
            target: address(target),
            selector: ExecutionSemanticsTarget.execute.selector,
            calldataHash: keccak256(payload),
            amount: amount,
            value: value,
            proofModuleKey: bytes32(0),
            proofId: 0,
            nonce: nonce,
            validAfter: block.timestamp,
            deadline: block.timestamp + 1 hours
        });
    }

    function _sign(AkmenaExecutionAuthorization.ExecutionIntent memory intent) internal view returns (bytes memory) {
        bytes32 digest = boundary.executionAuthorization().hashIntent(intent);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(agentPk, digest);

        return abi.encodePacked(r, s, v);
    }

    function test_DownstreamTargetSeesPolicyBoundaryAsSender() public {
        uint256 value = 1 ether;

        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _intent(value, value, 0);

        bytes memory payload = abi.encodeWithSelector(ExecutionSemanticsTarget.execute.selector, bytes("AKMENA"));

        bytes memory signature = _sign(intent);

        vm.prank(agent);

        boundary.executeAuthorizedAgentCall{value: value}(intent, payload, signature);

        assertEq(target.observedSender(), address(boundary), "Unexpected downstream msg.sender");
    }

    function test_DownstreamTargetReceivesExactAuthorizedValue() public {
        uint256 value = 1 ether;

        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _intent(value, value, 0);

        bytes memory payload = abi.encodeWithSelector(ExecutionSemanticsTarget.execute.selector, bytes("AKMENA"));

        bytes memory signature = _sign(intent);

        vm.prank(agent);

        boundary.executeAuthorizedAgentCall{value: value}(intent, payload, signature);

        assertEq(target.observedValue(), value, "Downstream value mismatch");
    }

    function test_UnauthorizedValueCannotBeForwarded() public {
        uint256 authorizedValue = 1 ether;
        uint256 suppliedValue = 2 ether;

        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _intent(authorizedValue, authorizedValue, 0);

        bytes memory payload = abi.encodeWithSelector(ExecutionSemanticsTarget.execute.selector, bytes("AKMENA"));

        bytes memory signature = _sign(intent);

        vm.prank(agent);

        vm.expectRevert(AkmenaExecutionAuthorization.InvalidCalldataHash.selector);

        boundary.executeAuthorizedAgentCall{value: suppliedValue}(intent, payload, signature);
    }

    function test_CalldataActuallyExecutedMatchesAuthorizedHash() public {
        uint256 value = 0;

        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _intent(0, value, 0);

        bytes memory payload = abi.encodeWithSelector(ExecutionSemanticsTarget.execute.selector, bytes("AKMENA"));

        bytes memory signature = _sign(intent);

        vm.prank(agent);

        boundary.executeAuthorizedAgentCall(intent, payload, signature);

        assertEq(
            keccak256(target.observedCalldata()),
            keccak256(payload),
            "Executed calldata differs from authorized calldata"
        );
    }

    function test_MutatedPayloadCannotReachTarget() public {
        uint256 value = 0;

        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _intent(0, value, 0);

        bytes memory maliciousPayload =
            abi.encodeWithSelector(ExecutionSemanticsTarget.execute.selector, bytes("MALICIOUS"));

        bytes memory signature = _sign(intent);

        vm.prank(agent);

        vm.expectRevert(AkmenaExecutionAuthorization.InvalidCalldataHash.selector);

        boundary.executeAuthorizedAgentCall(intent, maliciousPayload, signature);

        assertEq(target.observedSender(), address(0), "Target was reached with unauthorized calldata");
    }
}
