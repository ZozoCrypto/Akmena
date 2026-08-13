// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {EscrowEngine} from "../../src/economics/EscrowEngine.sol";

contract AttackWave3_EscrowCallerConfusionTest is Test {
    EscrowEngine internal escrow;

    address internal buyer = address(0x1111);
    address internal seller = address(0x2222);
    address internal attacker = address(0xBEEF);

    function setUp() public {
        escrow = new EscrowEngine();

        // Must prank as buyer to pass our earlier V2 authorization patch
        vm.prank(buyer);
        escrow.createEscrow(buyer, seller, 100 ether);
    }

    function test_Attack_AttackerCannotSpoofBuyer() public {
        // EXPLOIT ATTEMPT: Attacker calls releaseEscrow with just the ID.
        // Because EscrowEngine derives authorization strictly from msg.sender,
        // this must mathematically revert.
        vm.prank(attacker);
        vm.expectRevert(bytes4(keccak256("UnauthorizedAccess()")));
        escrow.releaseEscrow(1);
    }
}
