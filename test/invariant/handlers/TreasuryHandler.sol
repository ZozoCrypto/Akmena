// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {TreasuryEngine} from "../../../src/economics/TreasuryEngine.sol";

contract TreasuryHandler is Test {
    TreasuryEngine public immutable treasury;

    uint256 public totalFunded;
    uint256 public totalDisbursed;
    uint256 public fundCount;
    uint256 public disburseCount;
    uint256 public supplyUpdateCount;

    constructor(TreasuryEngine _treasury) {
        treasury = _treasury;
    }

    function fundTreasury(uint256 amount) external {
        amount = bound(amount, 1, type(uint128).max);

        try treasury.fundTreasury(amount) {
            totalFunded += amount;
            fundCount++;
        } catch {}
    }

    function disburseFunds(address to, uint256 amount) external {
        to = to == address(0) ? address(0x1) : to;
        amount = bound(amount, 1, type(uint128).max);

        (,, uint256 currentBalance) = treasury.getTreasuryState();

        if (amount <= currentBalance) {
            try treasury.disburseFunds(to, amount) {
                totalDisbursed += amount;
                disburseCount++;
            } catch {}
        } else {
            // Attempt over-disbursement to ensure it correctly reverts
            try treasury.disburseFunds(to, amount) {
                // Should never succeed
            } catch {}
        }
    }

    function updateSupply(uint256 total, uint256 circulating) external {
        total = bound(total, 0, type(uint128).max);
        circulating = bound(circulating, 0, total);

        try treasury.updateSupply(total, circulating) {
            supplyUpdateCount++;
        } catch {}
    }
}
