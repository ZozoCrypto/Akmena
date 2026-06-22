// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../interfaces/ISettlementEngine.sol";

/// @title Akmena Settlement Engine
/// @notice Permanent settlement ledger for completed protocol payments.
contract SettlementEngine is ISettlementEngine {
    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    error SettlementAlreadyExists();
    error SettlementNotFound();
    error InvalidParticipant();
    error InvalidAmount();

    // -------------------------------------------------------------------------
    // Storage
    // -------------------------------------------------------------------------

    mapping(bytes32 => Settlement) internal settlements;

    // -------------------------------------------------------------------------
    // Settlement Recording
    // -------------------------------------------------------------------------

    function recordSettlement(bytes32 settlementId, bytes32 escrowId, address payer, address payee, uint256 amount)
        external
    {
        if (exists(settlementId)) {
            revert SettlementAlreadyExists();
        }

        if (payer == address(0) || payee == address(0)) {
            revert InvalidParticipant();
        }

        if (amount == 0) {
            revert InvalidAmount();
        }

        settlements[settlementId] = Settlement({
            id: settlementId,
            escrowId: escrowId,
            payer: payer,
            payee: payee,
            amount: amount,
            settledAt: uint64(block.timestamp)
        });

        emit SettlementRecorded(settlementId, escrowId, payer, payee, amount);
    }

    // -------------------------------------------------------------------------
    // Views
    // -------------------------------------------------------------------------

    function exists(bytes32 settlementId) public view returns (bool) {
        return settlements[settlementId].settledAt != 0;
    }

    function getSettlement(bytes32 settlementId) external view returns (Settlement memory) {
        if (!exists(settlementId)) {
            revert SettlementNotFound();
        }

        return settlements[settlementId];
    }
}
