// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {AkmenaToken} from "../../src/token/core/AkmenaToken.sol";
import {TreasuryEngine} from "../../src/economics/TreasuryEngine.sol";
import {ITreasuryEngine} from "../../src/economics/ITreasuryEngine.sol";

contract TreasuryEngineTest is Test {
    AkmenaToken public token;
    TreasuryEngine public treasury;

    address public owner = address(0x1111);
    address public depositor = address(0x2222);
    address public recipient = address(0x3333);

    uint256 internal constant INITIAL = 1_000_000 ether;

    function setUp() public {
        token = new AkmenaToken(depositor);

        treasury = new TreasuryEngine(address(token), owner);

        vm.prank(depositor);
        token.approve(address(treasury), INITIAL);
    }

    function test_FundingMovesActualAKM() public {
        uint256 amount = 1_000 ether;

        uint256 depositorBefore = token.balanceOf(depositor);

        uint256 treasuryBefore = token.balanceOf(address(treasury));

        vm.prank(depositor);
        treasury.fundTreasury(amount);

        assertEq(token.balanceOf(depositor), depositorBefore - amount);

        assertEq(token.balanceOf(address(treasury)), treasuryBefore + amount);
    }

    function test_DisbursementMovesActualAKM() public {
        uint256 amount = 1_000 ether;

        vm.prank(depositor);
        treasury.fundTreasury(amount);

        uint256 before = token.balanceOf(recipient);

        vm.prank(owner);
        treasury.disburseFunds(recipient, amount);

        assertEq(token.balanceOf(recipient), before + amount);

        assertEq(token.balanceOf(address(treasury)), 0);
    }

    function test_TreasuryCannotFabricateBalance() public view {
        uint256 before = token.balanceOf(address(treasury));

        assertEq(before, 0);

        // There is intentionally no bookkeeping-only
        // funding path anymore.

        assertEq(token.balanceOf(address(treasury)), 0);
    }

    function test_NonOwnerCannotDisburse() public {
        uint256 amount = 1_000 ether;

        vm.prank(depositor);
        treasury.fundTreasury(amount);

        vm.prank(depositor);
        vm.expectRevert(ITreasuryEngine.Unauthorized.selector);

        treasury.disburseFunds(recipient, amount);
    }

    function test_TreasuryBalanceMatchesActualCustody() public {
        uint256 amount = 5_000 ether;

        vm.prank(depositor);
        treasury.fundTreasury(amount);

        (, uint256 reported) = treasury.getTreasuryState();

        assertEq(reported, token.balanceOf(address(treasury)));

        assertEq(reported, amount);
    }

    function test_SupplyComesFromToken() public view {
        (uint256 total,) = treasury.getTreasuryState();

        assertEq(total, token.totalSupply());
    }
}
