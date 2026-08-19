// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {TreasuryEngine} from "../../../src/economics/TreasuryEngine.sol";

contract Attack_TreasurySupplySpoofTest is Test {
    TreasuryEngine internal treasury;

    address internal attacker = address(0xBEEF);

    function setUp() public {
        treasury = new TreasuryEngine();
    }

    function test_Attack_AnyoneCanRewriteSupplyAccounting() public {
        vm.prank(attacker);

        treasury.updateSupply(type(uint256).max, type(uint256).max);

        (uint256 total, uint256 circulating, uint256 balance) = treasury.getTreasuryState();

        assertEq(total, type(uint256).max);
        assertEq(circulating, type(uint256).max);
        assertEq(balance, 0);
    }
}
