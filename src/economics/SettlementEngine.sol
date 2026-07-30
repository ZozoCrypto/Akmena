// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ISettlementEngine} from "./ISettlementEngine.sol";
import {LibStorage} from "../storage/LibStorage.sol";

contract SettlementEngine is ISettlementEngine {
    function recordSettlement(bytes32 settlementId, address payer, address payee, uint256 amount) external override {
        if (payer == address(0) || payee == address(0)) revert InvalidAddress();
        if (amount == 0) revert InvalidAmount();

        LibStorage.SettlementStorage storage ds = LibStorage.settlement();
        
        if (ds.records[settlementId].timestamp != 0) {
            revert SettlementAlreadyExists();
        }

        ds.records[settlementId] = LibStorage.SettlementData({
            payer: payer,
            payee: payee,
            amount: amount,
            timestamp: block.timestamp
        });

        emit SettlementRecorded(settlementId, payer, payee, amount);
    }

    function getSettlement(bytes32 settlementId) external view override returns (LibStorage.SettlementData memory) {
        LibStorage.SettlementStorage storage ds = LibStorage.settlement();
        if (ds.records[settlementId].timestamp == 0) revert SettlementNotFound();
        return ds.records[settlementId];
    }

    function exists(bytes32 settlementId) external view override returns (bool) {
        return LibStorage.settlement().records[settlementId].timestamp != 0;
    }
}
