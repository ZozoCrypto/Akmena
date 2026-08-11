// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {AkmenaCore} from "../../src/core/AkmenaCore.sol";
import {EscrowEngine} from "../../src/economics/EscrowEngine.sol";

contract AttackWave2_PrivilegeEscalationTest is Test {
    AkmenaCore internal core;
    EscrowEngine internal escrow;

    address internal admin = address(0xAD111);
    address internal attacker = address(0xBAD);

    function setUp() public {
        vm.startPrank(admin);
        
        // Deploy Core Router and Escrow
        core = new AkmenaCore();
        escrow = new EscrowEngine();

        // Register Escrow into Core
        core.registerModule(bytes32("ESCROW_ENGINE"), address(escrow), "2.0.0");
        vm.stopPrank();
    }

    // =========================================================================
    // 1. ESCROW PRIVILEGE ESCALATION ATTACK
    // =========================================================================

    function test_Attack_DirectEscrowReleaseBypass() public {
        uint256 escrowId = 1;
        
        // The attacker tries to call releaseEscrow directly on the EscrowEngine
        // bypassing the Core Router's security layer.
        vm.startPrank(attacker);
        
        // If this succeeds, the Escrow Engine is naked to the internet.
        // It MUST REVERT because only the Core Router (or authorized accounts) 
        // should be allowed to interact with raw escrow states.
        vm.expectRevert(); 
        escrow.releaseEscrow(escrowId);
        
        vm.stopPrank();
    }

    // =========================================================================
    // 2. CORE ROUTER REGISTRY HIJACK ATTACK
    // =========================================================================

    function test_Attack_CoreRouterModuleHijack() public {
        // Attacker deploys a malicious fake Escrow Engine
        address maliciousEscrow = address(0xDEADBEEF);
        
        vm.startPrank(attacker);

        // Attacker attempts to overwrite the real ESCROW_ENGINE registry
        // with their malicious contract to intercept all protocol funds.
        // This MUST revert with a permissions error.
        vm.expectRevert();
        core.registerModule(bytes32("ESCROW_ENGINE"), maliciousEscrow, "3.0.0");
        
        vm.stopPrank();
    }
}
