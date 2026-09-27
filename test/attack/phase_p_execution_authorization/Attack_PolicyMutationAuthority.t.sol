// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AkmenaCore} from "../../../src/core/AkmenaCore.sol";

import {Test} from "forge-std/Test.sol";
import {AkmenaPolicyBoundary} from "../../../src/authorization/AkmenaPolicyBoundary.sol";

contract AttackPolicyMutationAuthorityTest is Test {
    AkmenaPolicyBoundary internal boundary;
    AkmenaCore internal core;

    address internal operatorA = address(0xAAAA);

    address internal operatorB = address(0xBBBB);

    address internal agent = address(0xCCCC);

    address internal attacker = address(0xBEEF);

    function setUp() public {
        core = new AkmenaCore();
        boundary = new AkmenaPolicyBoundary(address(core));
    }

    function test_OperatorCannotOverwriteAnotherOperatorsPolicy() public {
        vm.prank(operatorA);

        boundary.setAgentPolicy(agent, 10 ether, 20 ether, false);

        vm.prank(operatorB);

        boundary.setAgentPolicy(agent, 1 ether, 2 ether, true);

        (uint256 maxA, uint256 dailyA, uint256 spentA, uint256 resetA, bool escrowA) =
            boundary.agentPolicies(operatorA, agent);

        (uint256 maxB, uint256 dailyB, uint256 spentB, uint256 resetB, bool escrowB) =
            boundary.agentPolicies(operatorB, agent);

        assertEq(maxA, 10 ether);
        assertEq(dailyA, 20 ether);
        assertEq(spentA, 0);
        assertTrue(resetA > 0);
        assertFalse(escrowA);

        assertEq(maxB, 1 ether);
        assertEq(dailyB, 2 ether);
        assertEq(spentB, 0);
        assertTrue(resetB > 0);
        assertTrue(escrowB);
    }

    function test_AttackerCannotModifyVictimOperatorsPolicy() public {
        vm.prank(operatorA);

        boundary.setAgentPolicy(agent, 10 ether, 20 ether, false);

        // Attacker creates a policy in the attacker's
        // own namespace. This must NOT affect operatorA.
        vm.prank(attacker);

        boundary.setAgentPolicy(agent, 999 ether, 999 ether, true);

        (uint256 maxSpend, uint256 dailyLimit, uint256 spentToday,, bool requireEscrow) =
            boundary.agentPolicies(operatorA, agent);

        assertEq(maxSpend, 10 ether, "CRITICAL: attacker modified victim operator policy");

        assertEq(dailyLimit, 20 ether, "CRITICAL: attacker modified victim daily limit");

        assertEq(spentToday, 0);

        assertFalse(requireEscrow, "CRITICAL: attacker modified victim escrow requirement");
    }

    function test_PoliciesAreIsolatedByOperatorAndAgent() public {
        address secondAgent = address(0xDDDD);

        vm.prank(operatorA);

        boundary.setAgentPolicy(agent, 10 ether, 20 ether, false);

        vm.prank(operatorA);

        boundary.setAgentPolicy(secondAgent, 30 ether, 40 ether, true);

        (uint256 maxFirst, uint256 dailyFirst,,, bool escrowFirst) = boundary.agentPolicies(operatorA, agent);

        (uint256 maxSecond, uint256 dailySecond,,, bool escrowSecond) = boundary.agentPolicies(operatorA, secondAgent);

        assertEq(maxFirst, 10 ether);
        assertEq(dailyFirst, 20 ether);
        assertFalse(escrowFirst);

        assertEq(maxSecond, 30 ether);
        assertEq(dailySecond, 40 ether);
        assertTrue(escrowSecond);
    }

    function test_AttackerPolicyDoesNotBecomeVictimPolicy() public {
        vm.prank(operatorA);

        boundary.setAgentPolicy(agent, 10 ether, 20 ether, false);

        vm.prank(attacker);

        boundary.setAgentPolicy(agent, 999 ether, 999 ether, true);

        (uint256 victimMax, uint256 victimDaily,,, bool victimEscrow) = boundary.agentPolicies(operatorA, agent);

        (uint256 attackerMax, uint256 attackerDaily,,, bool attackerEscrow) = boundary.agentPolicies(attacker, agent);

        assertEq(victimMax, 10 ether);
        assertEq(victimDaily, 20 ether);
        assertFalse(victimEscrow);

        assertEq(attackerMax, 999 ether);
        assertEq(attackerDaily, 999 ether);
        assertTrue(attackerEscrow);
    }

    function test_ZeroPolicyIsStillNotImplicitAuthorization() public view {
        (uint256 maxSpend, uint256 dailyLimit, uint256 spentToday,, bool requireEscrow) =
            boundary.agentPolicies(operatorA, agent);

        assertEq(maxSpend, 0);
        assertEq(dailyLimit, 0);
        assertEq(spentToday, 0);
        assertFalse(requireEscrow);
    }
}
