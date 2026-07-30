// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {TreasuryEngine} from "../../src/economics/TreasuryEngine.sol";
import {ITreasuryEngine} from "../../src/economics/ITreasuryEngine.sol";

contract TreasuryEngineTest is Test {
    TreasuryEngine public engine;
    address public payee = address(0x555);

    function setUp() public {
        engine = new TreasuryEngine();
    }

    function test_FundTreasury() public {
        vm.expectEmit(true, true, true, true);
        emit ITreasuryEngine.TreasuryFunded(1000);

        engine.fundTreasury(1000);
        (,, uint256 balance) = engine.getTreasuryState();
        assertEq(balance, 1000, "Balance should be 1000");
    }

    function test_DisburseFunds() public {
        engine.fundTreasury(5000);

        vm.expectEmit(true, true, true, true);
        emit ITreasuryEngine.FundsDisbursed(payee, 2000);

        engine.disburseFunds(payee, 2000);
        (,, uint256 balance) = engine.getTreasuryState();
        assertEq(balance, 3000, "Balance should be 3000");
    }

    function test_UpdateSupply() public {
        vm.expectEmit(true, true, true, true);
        emit ITreasuryEngine.SupplyUpdated(1000000, 500000);

        engine.updateSupply(1000000, 500000);
        (uint256 total, uint256 circulating,) = engine.getTreasuryState();
        assertEq(total, 1000000, "Total supply mismatch");
        assertEq(circulating, 500000, "Circulating supply mismatch");
    }

    function test_RevertWhen_FundingZeroAmount() public {
        vm.expectRevert(ITreasuryEngine.InvalidAmount.selector);
        engine.fundTreasury(0);
    }

    function test_RevertWhen_DisbursingZeroAmount() public {
        engine.fundTreasury(1000);
        vm.expectRevert(ITreasuryEngine.InvalidAmount.selector);
        engine.disburseFunds(payee, 0);
    }

    function test_RevertWhen_DisbursingToZeroAddress() public {
        engine.fundTreasury(1000);
        vm.expectRevert(ITreasuryEngine.InvalidAddress.selector);
        engine.disburseFunds(address(0), 500);
    }

    function test_RevertWhen_InsufficientTreasuryFunds() public {
        engine.fundTreasury(1000);
        vm.expectRevert(ITreasuryEngine.InsufficientTreasuryFunds.selector);
        engine.disburseFunds(payee, 2000);
    }
}
