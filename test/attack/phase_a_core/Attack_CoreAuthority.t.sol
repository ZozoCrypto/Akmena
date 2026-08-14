// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaCore} from "../../../src/core/AkmenaCore.sol";
import {EscrowEngine} from "../../../src/economics/EscrowEngine.sol";

contract Attack_CoreAuthorityTest is Test {
    AkmenaCore internal core;
    EscrowEngine internal escrow;

    address internal admin = address(0xAD111);
    address internal attacker = address(0xBAD);

    bytes32 constant ESCROW_KEY = bytes32("ESCROW_ENGINE");

    function setUp() public {
        vm.startPrank(admin);
        core = new AkmenaCore();
        escrow = new EscrowEngine();

        // Admin legitimately registers the Escrow Engine
        core.registerModule(ESCROW_KEY, address(escrow), "2.1.0");
        vm.stopPrank();
    }

    // =========================================================================
    // PHASE A: CORE AUTHORITY ATTACKS
    // =========================================================================

    function test_Attack_UnauthorizedModuleOverwrite() public {
        address maliciousEscrow = address(0xDEADBEEF);

        vm.prank(attacker);

        // EXPLOIT ATTEMPT: Attacker tries to overwrite the official EscrowEngine
        // with a malicious contract to route all funds to themselves.
        // EXPECTED: Revert due to lack of ownership/admin authority.
        vm.expectRevert();
        core.registerModule(ESCROW_KEY, maliciousEscrow, "3.0.0");

        // VERIFY STATE: Ensure the module was NOT overwritten
        (address currentEscrow, bool isActive,) = core.getModule(ESCROW_KEY);
        assertEq(currentEscrow, address(escrow), "CRITICAL: Attacker overwrote core module!");
        assertTrue(isActive, "CRITICAL: Attacker disabled core module!");
    }

    function test_Attack_UnauthorizedModuleDisabling() public {
        vm.prank(attacker);

        // EXPLOIT ATTEMPT: Attacker tries to disable the EscrowEngine,
        // causing a Denial of Service (DoS) across the entire autonomous economy.
        // EXPECTED: Revert due to lack of ownership/admin authority.
        vm.expectRevert();
        core.setModuleStatus(ESCROW_KEY, false);

        // VERIFY STATE: Ensure the module is still active
        (, bool isActive,) = core.getModule(ESCROW_KEY);
        assertTrue(isActive, "CRITICAL: Attacker successfully disabled a core module!");
    }

    function test_Attack_ModuleAddressSpoofingViaStatePollution() public {
        // EXPLOIT ATTEMPT: Attacker attempts to register a slightly different bytes32 key
        // hoping downstream contracts use loose string matching or partial hashes.
        bytes32 spoofedKey = bytes32("ESCROW_ENGINE_V2");
        address spoofedEscrow = address(0x999);

        vm.prank(attacker);
        vm.expectRevert();
        core.registerModule(spoofedKey, spoofedEscrow, "1.0.0");
    }
}
