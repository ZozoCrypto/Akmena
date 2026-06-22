// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title Akmena Settlement Engine Interface
/// @notice Permanent settlement records for completed protocol payments.
interface ISettlementEngine {
    // -------------------------------------------------------------------------
    // Structs
    // -------------------------------------------------------------------------

    struct Settlement {
        bytes32 id;
        bytes32 escrowId;

        address payer;
        address payee;

        uint256 amount;

        uint64 settledAt;
    }

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    event SettlementRecorded(
        bytes32 indexed settlementId, bytes32 indexed escrowId, address indexed payer, address payee, uint256 amount
    );

    // -------------------------------------------------------------------------
    // Actions
    // -------------------------------------------------------------------------

    function recordSettlement(bytes32 settlementId, bytes32 escrowId, address payer, address payee, uint256 amount)
        external;

    // -------------------------------------------------------------------------
    // Views
    // -------------------------------------------------------------------------

    function exists(bytes32 settlementId) external view returns (bool);

    function getSettlement(bytes32 settlementId) external view returns (Settlement memory);
}
