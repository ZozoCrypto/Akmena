// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ITreasuryEngine} from "./ITreasuryEngine.sol";
import {LibStorage} from "../storage/LibStorage.sol";

contract TreasuryEngine is ITreasuryEngine {
    function fundTreasury(uint256 amount) external override {
        if (amount == 0) revert InvalidAmount();

        LibStorage.TreasuryStorage storage ds = LibStorage.treasury();
        ds.treasuryBalance += amount;

        emit TreasuryFunded(amount);
    }

    function disburseFunds(address to, uint256 amount) external override {
        if (to == address(0)) revert InvalidAddress();
        if (amount == 0) revert InvalidAmount();

        LibStorage.TreasuryStorage storage ds = LibStorage.treasury();
        if (ds.treasuryBalance < amount) revert InsufficientTreasuryFunds();

        ds.treasuryBalance -= amount;
        emit FundsDisbursed(to, amount);
    }

    function updateSupply(uint256 total, uint256 circulating) external override {
        LibStorage.TreasuryStorage storage ds = LibStorage.treasury();
        ds.totalSupply = total;
        ds.circulatingSupply = circulating;

        emit SupplyUpdated(total, circulating);
    }

    function getTreasuryState() external view override returns (uint256 total, uint256 circulating, uint256 balance) {
        LibStorage.TreasuryStorage storage ds = LibStorage.treasury();
        return (ds.totalSupply, ds.circulatingSupply, ds.treasuryBalance);
    }
}
