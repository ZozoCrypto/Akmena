// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AkmenaCore} from "../../../src/core/AkmenaCore.sol";

import {Test} from "forge-std/Test.sol";

import {AkmenaPolicyBoundary} from "../../../src/authorization/AkmenaPolicyBoundary.sol";

import {AkmenaExecutionAuthorization} from "../../../src/authorization/AkmenaExecutionAuthorization.sol";

contract DailyResetTarget {
    uint256 public calls;
    uint256 public lastAmount;

    function execute(uint256 amount) external returns (bool) {
        calls += 1;
        lastAmount = amount;
        return true;
    }
}

contract AttackPolicyDailyResetTest is Test {
    AkmenaPolicyBoundary internal boundary;
    AkmenaCore internal core;
    AkmenaExecutionAuthorization internal authorization;
    DailyResetTarget internal target;

    uint256 internal constant AGENT_KEY = 0xA11CE;

    address internal agent;
    address internal operator = address(0xAAAA);

    function setUp() public {
        core = new AkmenaCore();

        boundary = new AkmenaPolicyBoundary(address(core));

        authorization = boundary.executionAuthorization();

        target = new DailyResetTarget();

        agent = vm.addr(AGENT_KEY);

        vm.prank(operator);

        boundary.setAgentPolicy(agent, 10 ether, 10 ether, false);
    }

    function _intent(uint256 amount, uint256 nonce)
        internal
        view
        returns (AkmenaExecutionAuthorization.ExecutionIntent memory)
    {
        bytes memory payload = abi.encodeWithSelector(DailyResetTarget.execute.selector, amount);

        return AkmenaExecutionAuthorization.ExecutionIntent({
            operator: operator,
            agent: agent,
            target: address(target),
            selector: DailyResetTarget.execute.selector,
            calldataHash: keccak256(payload),
            amount: amount,
            value: 0,
            proofModuleKey: bytes32(0),
            proofId: 0,
            nonce: nonce,
            validAfter: block.timestamp,
            deadline: block.timestamp + 1 days
        });
    }

    function _sign(AkmenaExecutionAuthorization.ExecutionIntent memory intent) internal view returns (bytes memory) {
        bytes32 digest = authorization.hashIntent(intent);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(AGENT_KEY, digest);

        return abi.encodePacked(r, s, v);
    }

    function test_DailyLimitIsConsumed() public {
        uint256 amount = 10 ether;

        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _intent(amount, 0);

        bytes memory payload = abi.encodeWithSelector(DailyResetTarget.execute.selector, amount);

        bytes memory signature = _sign(intent);

        vm.prank(agent);

        boundary.executeAuthorizedAgentCall(intent, payload, signature);

        assertEq(target.calls(), 1);

        (,, uint256 spentToday,,) = boundary.agentPolicies(operator, agent);

        assertEq(spentToday, 10 ether);
    }

    function test_SpendAboveDailyLimitIsRejectedSameDay() public {
        uint256 firstAmount = 6 ether;

        uint256 secondAmount = 5 ether;

        AkmenaExecutionAuthorization.ExecutionIntent memory first = _intent(firstAmount, 0);

        bytes memory firstPayload = abi.encodeWithSelector(DailyResetTarget.execute.selector, firstAmount);

        bytes memory firstSignature = _sign(first);

        vm.prank(agent);

        boundary.executeAuthorizedAgentCall(first, firstPayload, firstSignature);

        AkmenaExecutionAuthorization.ExecutionIntent memory second = _intent(secondAmount, 1);

        bytes memory secondPayload = abi.encodeWithSelector(DailyResetTarget.execute.selector, secondAmount);

        bytes memory secondSignature = _sign(second);

        vm.prank(agent);

        vm.expectRevert(AkmenaPolicyBoundary.PolicyExceeded.selector);

        boundary.executeAuthorizedAgentCall(second, secondPayload, secondSignature);

        assertEq(target.calls(), 1);
    }

    function test_DailyLimitShouldResetAfterOneDay() public {
        uint256 amount = 10 ether;

        AkmenaExecutionAuthorization.ExecutionIntent memory first = _intent(amount, 0);

        bytes memory firstPayload = abi.encodeWithSelector(DailyResetTarget.execute.selector, amount);

        bytes memory firstSignature = _sign(first);

        vm.prank(agent);

        boundary.executeAuthorizedAgentCall(first, firstPayload, firstSignature);

        assertEq(target.calls(), 1);

        // Move beyond the one-day reset window.
        vm.warp(block.timestamp + 1 days + 1);

        AkmenaExecutionAuthorization.ExecutionIntent memory second = _intent(amount, 1);

        bytes memory secondPayload = abi.encodeWithSelector(DailyResetTarget.execute.selector, amount);

        bytes memory secondSignature = _sign(second);

        vm.prank(agent);

        // This is the critical probe.
        //
        // Expected protocol behavior:
        // the previous day's spend should be reset,
        // allowing another 10 ETH execution.
        boundary.executeAuthorizedAgentCall(second, secondPayload, secondSignature);

        assertEq(target.calls(), 2, "CRITICAL: daily policy did not reset after one day");

        (,, uint256 spentToday, uint256 resetTimestamp,) = boundary.agentPolicies(operator, agent);

        assertEq(spentToday, 10 ether);

        assertEq(resetTimestamp, block.timestamp);
    }
}
