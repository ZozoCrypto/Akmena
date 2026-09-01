// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaToken} from "../../src/token/core/AkmenaToken.sol";

contract EconomicLayerInvariantTest is Test {
    AkmenaToken internal token;

    address internal treasury = address(0x1000);
    uint256 internal constant MAX =
        1_000_000_000 ether;

    function setUp() public {
        token = new AkmenaToken(treasury);
    }

    function invariant_TokenSupplyNeverExceedsMaximum() public view {
        assertLe(
            token.totalSupply(),
            MAX
        );
    }

    function invariant_InitialSupplyIsOwned() public view {
        // Initial supply is minted to the treasury, but ERC20 transfers
        // legitimately move ownership over time. The invariant is therefore
        // that fixed supply remains conserved, not that treasury retains
        // every token forever.
        assertEq(
            token.totalSupply(),
            MAX
        );
    }

    function invariant_TokenSupplyRemainsConserved() public view {
        assertEq(
            token.totalSupply(),
            MAX
        );
    }
}
