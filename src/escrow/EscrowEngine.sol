// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../interfaces/IEscrowEngine.sol";

/// @title Akmena Escrow Engine
/// @notice Manages escrowed payments between protocol participants.
contract EscrowEngine is IEscrowEngine {
    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    error EscrowAlreadyExists();
    error EscrowNotFound();
    error InvalidPayee();
    error InvalidAmount();
    error EscrowAlreadyReleased();
    error EscrowAlreadyRefunded();

    // -------------------------------------------------------------------------
    // Storage
    // -------------------------------------------------------------------------

    mapping(bytes32 => Escrow) internal escrows;

    // -------------------------------------------------------------------------
    // Escrow Creation
    // -------------------------------------------------------------------------

    function createEscrow(bytes32 escrowId, address payee) external payable {
        if (exists(escrowId)) {
            revert EscrowAlreadyExists();
        }

        if (payee == address(0)) {
            revert InvalidPayee();
        }

        if (msg.value == 0) {
            revert InvalidAmount();
        }

        escrows[escrowId] = Escrow({
            id: escrowId, payer: msg.sender, payee: payee, amount: msg.value, released: false, refunded: false
        });

        emit EscrowCreated(escrowId, msg.sender, payee, msg.value);
    }

    // -------------------------------------------------------------------------
    // Lifecycle
    // -------------------------------------------------------------------------

    function release(bytes32 escrowId) external {
        if (!exists(escrowId)) {
            revert EscrowNotFound();
        }

        Escrow storage escrow = escrows[escrowId];

        if (escrow.released) {
            revert EscrowAlreadyReleased();
        }

        if (escrow.refunded) {
            revert EscrowAlreadyRefunded();
        }

        escrow.released = true;

        payable(escrow.payee).transfer(escrow.amount);

        emit EscrowReleased(escrowId);
    }

    function refund(bytes32 escrowId) external {
        if (!exists(escrowId)) {
            revert EscrowNotFound();
        }

        Escrow storage escrow = escrows[escrowId];

        if (escrow.refunded) {
            revert EscrowAlreadyRefunded();
        }

        if (escrow.released) {
            revert EscrowAlreadyReleased();
        }

        escrow.refunded = true;

        payable(escrow.payer).transfer(escrow.amount);

        emit EscrowRefunded(escrowId);
    }

    // -------------------------------------------------------------------------
    // Views
    // -------------------------------------------------------------------------

    function exists(bytes32 escrowId) public view returns (bool) {
        return escrows[escrowId].payer != address(0);
    }

    function getEscrow(bytes32 escrowId) external view returns (Escrow memory) {
        if (!exists(escrowId)) {
            revert EscrowNotFound();
        }

        return escrows[escrowId];
    }
}
