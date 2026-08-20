// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {AkmenaCore} from "../../../src/core/AkmenaCore.sol";
import {AkmenaPolicyBoundary} from "../../../src/authorization/AkmenaPolicyBoundary.sol";

// Dummy contract that purposely reverts to simulate a failed AI action (e.g., slippage)
contract DummyTarget {
    function failAction() external pure {
        revert("Simulated Network/Slippage Failure");
    }
}

contract Attack_BoundaryDesyncTest is Test {
    AkmenaCore internal core;
    AkmenaPolicyBoundary internal boundary;
    DummyTarget internal target;

    address internal operator = address(0x1111);
    address internal agent = address(0x2222);

    function setUp() public {
        core = new AkmenaCore();
        boundary = new AkmenaPolicyBoundary(address(core));
        target = new DummyTarget();

        vm.prank(operator);
        boundary.setAgentPolicy(agent, 100 ether, 100 ether, false);
    }

    function test_Attack_AtomicRollbackPreventsPhantomSpend() public {
        vm.startPrank(agent);

        // EXPLOIT ATTEMPT: The AI Agent attempts an execution that is guaranteed to fail.
        bytes memory payload = abi.encodeWithSelector(DummyTarget.failAction.selector);

        vm.expectRevert("Simulated Network/Slippage Failure");
        boundary.executeAgentCall(operator, address(target), 100 ether, bytes32("ESCROW_ENGINE"), 0, payload);

        vm.stopPrank();

        // VERIFY STATE: Because the EVM guarantees atomicity, the agent's budget
        // MUST remain at 0. The phantom spend exploit is dead.
        (,, uint256 spentToday,,) = boundary.agentPolicies(operator, agent);
        assertEq(spentToday, 0, "CRITICAL: Agent budget drained despite failed execution!");
    }
}
