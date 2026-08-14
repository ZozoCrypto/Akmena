// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {EscrowEngine} from "../../../src/economics/EscrowEngine.sol";
import {LibStorage} from "../../../src/storage/LibStorage.sol";

contract Attack_ValueConservationTest is Test {
    EscrowEngine internal escrow;

    address internal buyer = address(0x1111);
    address internal seller = address(0x2222);

    function setUp() public {
        escrow = new EscrowEngine();

        // Setup a legitimate escrow
        vm.prank(buyer);
        escrow.createEscrow(buyer, seller, 100 ether);
    }

    // =========================================================================
    // PHASE B: MONEY (VALUE CONSERVATION ATTACKS)
    // =========================================================================

    function test_Attack_DoubleSpendViaRepeatedRelease() public {
        vm.startPrank(buyer);

        // First legitimate release
        escrow.releaseEscrow(1);

        // EXPLOIT ATTEMPT: Release the exact same escrow again to trick
        // the protocol into paying the seller double and draining reserves.
        // EXPECTED: Revert because the state machine should transition out of 'Funded'
        vm.expectRevert();
        escrow.releaseEscrow(1);

        vm.stopPrank();

        // VERIFY STATE
        LibStorage.EscrowData memory data = escrow.getEscrow(1);
        // Status should be mutated away from 1 (Funded) to prevent replay
        assertTrue(data.status != 1, "CRITICAL: Escrow status remained FUNDED after release!");
    }

    function test_Attack_ZeroValueEscrowGriefing() public {
        vm.startPrank(buyer);

        // EXPLOIT ATTEMPT: Attacker spams zero-value escrows to bloat state,
        // pollute the array, or bypass minimum threshold fee logic.
        // EXPECTED: The protocol should enforce a > 0 check to prevent griefing.
        vm.expectRevert();
        escrow.createEscrow(buyer, seller, 0);

        vm.stopPrank();
    }
}
