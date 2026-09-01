// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaToken} from "../../src/token/core/AkmenaToken.sol";
import {TreasuryEngine} from "../../src/economics/TreasuryEngine.sol";

contract TreasuryInvariantTest is Test {
    AkmenaToken internal token;
    TreasuryEngine internal treasury;

    address internal owner = address(0x1111);
    address internal depositor = address(0x2222);

    function setUp() public {
        token = new AkmenaToken(depositor);

        treasury = new TreasuryEngine(
            address(token),
            owner
        );

        vm.prank(depositor);
        token.approve(
            address(treasury),
            type(uint256).max
        );
    }

    function test_TreasuryBalanceEqualsActualTokenCustody()
        public
    {
        uint256 amount = 10_000 ether;

        vm.prank(depositor);
        treasury.fundTreasury(amount);

        (, uint256 reported) =
            treasury.getTreasuryState();

        assertEq(
            reported,
            token.balanceOf(address(treasury))
        );

        assertEq(reported, amount);
    }

    function test_TreasurySupplyEqualsTokenSupply()
        public
        view
    {
        (uint256 total,) =
            treasury.getTreasuryState();

        assertEq(
            total,
            token.totalSupply()
        );
    }

    function test_DisbursementPreservesCustodyAccounting()
        public
    {
        uint256 deposit = 10_000 ether;
        uint256 withdrawal = 4_000 ether;

        vm.prank(depositor);
        treasury.fundTreasury(deposit);

        uint256 before =
            token.balanceOf(address(treasury));

        vm.prank(owner);
        treasury.disburseFunds(
            depositor,
            withdrawal
        );

        uint256 afterBalance =
            token.balanceOf(address(treasury));

        assertEq(
            afterBalance,
            before - withdrawal
        );

        (, uint256 reported) =
            treasury.getTreasuryState();

        assertEq(
            reported,
            afterBalance
        );
    }
}
