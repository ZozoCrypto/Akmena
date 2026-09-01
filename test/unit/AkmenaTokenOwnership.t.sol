// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaToken} from "../../src/token/core/AkmenaToken.sol";

contract AkmenaTokenOwnershipTest is Test {
    uint256 internal constant MAX_SUPPLY =
        1_000_000_000 ether;

    address internal constant INITIAL_HOLDER =
        address(0x1000);

    AkmenaToken internal token;

    function setUp() public {
        token = new AkmenaToken(INITIAL_HOLDER);
    }

    function test_InitialHolderReceivesEntireInitialSupply() public view {
        assertEq(
            token.totalSupply(),
            MAX_SUPPLY
        );

        assertEq(
            token.balanceOf(INITIAL_HOLDER),
            MAX_SUPPLY
        );
    }

    function test_InitialHolderCanTransferOwnership() public {
        address recipient = address(0xBEEF);
        uint256 amount = 2_547;

        vm.prank(INITIAL_HOLDER);

        assertTrue(
            token.transfer(recipient, amount)
        );

        assertEq(
            token.balanceOf(INITIAL_HOLDER),
            MAX_SUPPLY - amount
        );

        assertEq(
            token.balanceOf(recipient),
            amount
        );

        assertEq(
            token.totalSupply(),
            MAX_SUPPLY
        );
    }
}
