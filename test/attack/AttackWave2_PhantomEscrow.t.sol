// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {EscrowEngine} from "../../src/economics/EscrowEngine.sol";
import {AkmenaToken} from "../../src/token/core/AkmenaToken.sol";
import {LibStorage} from "../../src/storage/LibStorage.sol";

contract AttackWave2_PhantomEscrowTest is Test {
    EscrowEngine internal escrow;
    AkmenaToken internal token;

    address internal attacker = address(0xBAD);
    address internal aiAgent = address(0xA1);

    function setUp() public {
        // We deploy the engine raw, exactly as it exists on chain
        token = new AkmenaToken(address(this));
        escrow = new EscrowEngine(address(token));
    }

    // =========================================================================
    // THE PHANTOM FUNDING EXPLOIT
    // =========================================================================

    function test_Attack_PhantomFundingSpoof() public {
        uint256 fakeAmount = 1_000_000 * 10 ** 18; // 1 Million Tokens

        // Attacker has exactly 0 actual tokens in their wallet
        assertEq(address(attacker).balance, 0);

        vm.startPrank(attacker);

        // 1. Attacker has no AKM and has granted no allowance.
        assertEq(token.balanceOf(attacker), 0);
        assertEq(token.allowance(attacker, address(escrow)), 0);

        // 2. EXPLOIT ATTEMPT: create a massive escrow without funding.
        // EXPECTED: The escrow MUST reject phantom funding.
        vm.expectRevert();

        escrow.createEscrow(attacker, aiAgent, fakeAmount);

        // No escrow record can be created without actual AKM custody.
        assertEq(token.balanceOf(address(escrow)), 0);

        vm.stopPrank();
    }
}
