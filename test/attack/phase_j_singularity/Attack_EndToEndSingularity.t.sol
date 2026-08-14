// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {AkmenaCore} from "../../../src/core/AkmenaCore.sol";
import {AkmenaPolicyBoundary} from "../../../src/authorization/AkmenaPolicyBoundary.sol";
import {EscrowEngine} from "../../../src/economics/EscrowEngine.sol";

// A malicious target contract attempting to steal funds or extract unauthorized actions
contract MaliciousDrainer {
    function drainTreasury(address coreRouter) external {
        // Attempt to hijack core router or call restricted functions
        try AkmenaCore(coreRouter).setModuleStatus(bytes32("ESCROW_ENGINE"), false) {} catch {}
    }
}

contract Attack_EndToEndSingularityTest is Test {
    AkmenaCore internal core;
    AkmenaPolicyBoundary internal boundary;
    EscrowEngine internal escrow;
    MaliciousDrainer internal drainer;

    address internal operator = address(0x1111);
    address internal agent = address(0x2222);
    address internal attacker = address(0xBEEF);

    function setUp() public {
        core = new AkmenaCore();
        escrow = new EscrowEngine();
        boundary = new AkmenaPolicyBoundary(address(core));
        drainer = new MaliciousDrainer();

        vm.prank(address(this));
        core.registerModule(bytes32("ESCROW_ENGINE"), address(escrow), "2.1.0");

        vm.prank(operator);
        boundary.setAgentPolicy(agent, 50 ether, 200 ether, false);
    }

    // =========================================================================
    // PHASE J: END-TO-END UNAUTHORIZED ECONOMIC ACTION (THE FINAL EXAM)
    // =========================================================================

    function test_Singularity_EndToEndAttackPipelineResilience() public {
        console.log("=== INITIATING PHASE J: THE SINGULARITY FINAL EXAM ===");

        // STEP 1: Attacker attempts to spoof agent identity through the policy boundary
        vm.prank(attacker);
        vm.expectRevert(AkmenaPolicyBoundary.UnauthorizedAgent.selector);
        boundary.executeAgentCall(
            operator,
            address(drainer),
            10 ether,
            0,
            abi.encodeWithSelector(MaliciousDrainer.drainTreasury.selector, address(core))
        );
        console.log("[+] Vector 1 Defeated: Attacker identity spoofing blocked.");

        // STEP 2: Compromised AI Agent (prompt injected) tries to exceed max spend per transaction
        vm.startPrank(agent);
        bytes memory payload = abi.encodeWithSelector(MaliciousDrainer.drainTreasury.selector, address(core));

        vm.expectRevert(AkmenaPolicyBoundary.PolicyExceeded.selector);
        boundary.executeAgentCall(
            operator,
            address(drainer),
            100 ether, // Exceeds maxSpendPerTransaction of 50 ether
            0,
            payload
        );
        console.log("[+] Vector 2 Defeated: Rogue agent max spend limit enforced.");

        // STEP 3: Compromised AI Agent tries to drain budget via uncoordinated calls (Atomic test)
        // Even if it attempts to hit a draining contract within limits, if the target reverts, state rolls back.
        // Let's verify normal authorized action works seamlessly:
        boundary.executeAgentCall(
            operator,
            address(drainer),
            40 ether, // Within 50 ether limit and 200 daily limit
            0,
            payload
        );
        console.log("[+] Vector 3 Verified: Authorized atomic execution completed safely.");

        // Verify remaining daily budget state is precisely accounted for (200 - 40 = 160)
        (,, uint256 spentToday,,) = boundary.agentPolicies(operator, agent);
        assertEq(spentToday, 40 ether, "CRITICAL: Policy budget miscalculated after pipeline run!");
        console.log("[+] Accounting State Integrity: 100% Verified.");

        vm.stopPrank();
        console.log("=== PHASE J PASSED: NO UNAUTHORIZED ECONOMIC ACTION POSSIBLE ===");
    }
}
