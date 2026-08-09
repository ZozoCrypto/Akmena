// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {TreasuryEngine} from "../../src/economics/TreasuryEngine.sol";
import {TreasuryHandler} from "./handlers/TreasuryHandler.sol";

contract TreasuryInvariant is StdInvariant, Test {
    TreasuryEngine internal treasury;
    TreasuryHandler internal handler;

    function setUp() public {
        treasury = new TreasuryEngine();
        handler = new TreasuryHandler(treasury);

        targetContract(address(handler));
    }

    function test_SanityCheck() public pure {
        assertTrue(true);
    }

    /// INVARIANT: Treasury balance must strictly match total funded minus total disbursed
    function invariant_balanceMatchesShadowAccounting() public view {
        (,, uint256 balance) = treasury.getTreasuryState();
        uint256 expectedBalance = handler.totalFunded() - handler.totalDisbursed();
        assertEq(balance, expectedBalance);
    }

    /// INVARIANT: Circulating supply must never exceed total supply
    function invariant_supplyBoundsValid() public view {
        (uint256 total, uint256 circulating,) = treasury.getTreasuryState();
        assertTrue(circulating <= total);
    }
}
