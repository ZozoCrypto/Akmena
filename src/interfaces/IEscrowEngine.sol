// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title Akmena Escrow Engine Interface
/// @notice Canonical interface for escrow-based payments.
interface IEscrowEngine {
    // -------------------------------------------------------------------------
    // Structs
    // -------------------------------------------------------------------------

    struct Escrow {
        bytes32 id;

        address payer;
        address payee;

        uint256 amount;

        bool released;
        bool refunded;
    }

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    event EscrowCreated(bytes32 indexed escrowId, address indexed payer, address indexed payee, uint256 amount);

    event EscrowReleased(bytes32 indexed escrowId);

    event EscrowRefunded(bytes32 indexed escrowId);

    // -------------------------------------------------------------------------
    // Actions
    // -------------------------------------------------------------------------

    function createEscrow(bytes32 escrowId, address payee) external payable;

    function release(bytes32 escrowId) external;

    function refund(bytes32 escrowId) external;

    // -------------------------------------------------------------------------
    // Views
    // -------------------------------------------------------------------------

    function exists(bytes32 escrowId) external view returns (bool);

    function getEscrow(bytes32 escrowId) external view returns (Escrow memory);
}
