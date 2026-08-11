// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {EscrowEngine} from "../../src/economics/EscrowEngine.sol";
import {LibStorage} from "../../src/storage/LibStorage.sol";

contract AttackWave2_PhantomEscrowTest is Test {
    EscrowEngine internal escrow;

    address internal attacker = address(0xBAD);
    address internal aiAgent = address(0xA1);

    function setUp() public {
        // We deploy the engine raw, exactly as it exists on chain
        escrow = new EscrowEngine();
    }

    // =========================================================================
    // THE PHANTOM FUNDING EXPLOIT
    // =========================================================================

    function test_Attack_PhantomFundingSpoof() public {
        uint256 fakeAmount = 1_000_000 * 10**18; // 1 Million Tokens

        // Attacker has exactly 0 actual tokens in their wallet
        assertEq(address(attacker).balance, 0);

        vm.startPrank(attacker);

        // 1. Attacker creates a massive escrow out of thin air.
        // It succeeds because there is no `transferFrom` or `msg.value` check.
        uint256 escrowId = escrow.createEscrow(attacker, aiAgent, fakeAmount);

        // 2. The AI Agent queries the blockchain to verify the escrow is funded
        LibStorage.EscrowData memory target = escrow.getEscrow(escrowId);

        // 3. EXPLOIT PROVEN: The protocol tells the AI Agent that the escrow 
        // is valid, fully funded, and ready to go. The attacker just stole the work.
        assertEq(target.buyer, attacker, "Buyer mismatch");
        assertEq(target.seller, aiAgent, "Seller mismatch");
        assertEq(target.amount, fakeAmount, "Amount was not recorded!");
        assertEq(target.status, 1, "Status is not FUNDED!");
        
        vm.stopPrank();
    }
}
