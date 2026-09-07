// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {AkmenaToken} from "../../../src/token/core/AkmenaToken.sol";
import {TreasuryEngine} from "../../../src/economics/TreasuryEngine.sol";
import {ITreasuryEngine} from "../../../src/economics/ITreasuryEngine.sol";

contract Attack_TreasuryAccountingSpoofTest is Test {
    AkmenaToken internal token;
    TreasuryEngine internal treasury;

    address internal owner = address(0x1111);
    address internal attacker = address(0xBEEF);
    address internal recipient = address(0xCAFE);

    uint256 internal constant INITIAL =
        1_000_000 ether;

    function setUp() public {
        token = new AkmenaToken(attacker);

        treasury = new TreasuryEngine(
            address(token),
            owner
        );
    }

    function test_Attack_CannotFabricateTreasuryBalance()
        public
    {
        uint256 before =
            token.balanceOf(address(treasury));

        vm.prank(attacker);

        vm.expectRevert();

        treasury.fundTreasury(1_000_000 ether);

        assertEq(
            token.balanceOf(address(treasury)),
            before
        );
    }

    function test_Attack_NonOwnerCannotDisburse()
        public
    {
        uint256 amount = 1_000 ether;

        vm.prank(attacker);
        token.approve(
            address(treasury),
            amount
        );

        vm.prank(attacker);
        treasury.fundTreasury(amount);

        uint256 attackerBefore =
            token.balanceOf(attacker);

        vm.prank(attacker);
        vm.expectRevert(
            ITreasuryEngine.Unauthorized.selector
        );

        treasury.disburseFunds(
            recipient,
            amount
        );

        assertEq(
            token.balanceOf(attacker),
            attackerBefore
        );
    }

    function test_OwnerDisbursementMovesRealAKM()
        public
    {
        uint256 amount = 5_000 ether;

        vm.prank(attacker);
        token.approve(
            address(treasury),
            amount
        );

        vm.prank(attacker);
        treasury.fundTreasury(amount);

        uint256 recipientBefore =
            token.balanceOf(recipient);

        uint256 treasuryBefore =
            token.balanceOf(address(treasury));

        vm.prank(owner);

        treasury.disburseFunds(
            recipient,
            amount
        );

        assertEq(
            token.balanceOf(recipient),
            recipientBefore + amount
        );

        assertEq(
            token.balanceOf(address(treasury)),
            treasuryBefore - amount
        );
    }
}
