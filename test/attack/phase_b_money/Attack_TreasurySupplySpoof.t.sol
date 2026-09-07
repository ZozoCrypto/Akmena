// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {AkmenaToken} from "../../../src/token/core/AkmenaToken.sol";
import {TreasuryEngine} from "../../../src/economics/TreasuryEngine.sol";

contract Attack_TreasurySupplySpoofTest is Test {
    AkmenaToken internal token;
    TreasuryEngine internal treasury;

    address internal owner = address(0x1111);
    address internal holder = address(0x2222);

    function setUp() public {
        token = new AkmenaToken(holder);

        treasury = new TreasuryEngine(
            address(token),
            owner
        );
    }

    function test_TreasuryReportsTokenSupply()
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

    function test_TreasuryHasNoIndependentSupplyState()
        public
        view
    {
        // Supply is owned by the monetary layer.
        assertEq(
            treasury.token(),
            address(token)
        );
    }
}
