// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {LibStorage} from "../storage/LibStorage.sol";
import {IEscrowEngine} from "./IEscrowEngine.sol";

contract EscrowEngine is IEscrowEngine {
    uint256 private _nextEscrowId = 1;

    function createEscrow(address buyer, address seller, uint256 amount) external returns (uint256) {
        if (amount == 0) revert InvalidAmount();
        if (buyer == address(0) || seller == address(0)) revert InvalidAddress();

        uint256 escrowId = _nextEscrowId++;
        LibStorage.EscrowData memory data = LibStorage.EscrowData({
            buyer: buyer,
            seller: seller,
            amount: amount,
            status: 1 // Funded / Active
        });

        LibStorage.escrow().escrows[escrowId] = data;
        emit EscrowCreated(escrowId, buyer, seller, amount);
        return escrowId;
    }

    function releaseEscrow(uint256 escrowId) external {
        LibStorage.EscrowData storage data = LibStorage.escrow().escrows[escrowId];
        if (data.buyer == address(0)) revert EscrowNotFound();
        if (data.status != 1) revert EscrowNotActive();
        if (msg.sender != data.buyer) revert UnauthorizedAccess();

        data.status = 2; // Released
        emit EscrowReleased(escrowId);
    }

    function refundEscrow(uint256 escrowId) external {
        LibStorage.EscrowData storage data = LibStorage.escrow().escrows[escrowId];
        if (data.buyer == address(0)) revert EscrowNotFound();
        if (data.status != 1) revert EscrowNotActive();
        if (msg.sender != data.seller) revert UnauthorizedAccess();

        data.status = 3; // Refunded
        emit EscrowRefunded(escrowId);
    }

    function getEscrow(uint256 escrowId) external view returns (LibStorage.EscrowData memory) {
        LibStorage.EscrowData memory data = LibStorage.escrow().escrows[escrowId];
        if (data.buyer == address(0)) revert EscrowNotFound();
        return data;
    }

    /// @notice Unified interface for the PolicyBoundary dynamic routing
    function verifyTransientProof(uint256 proofId, address operator, uint256 amount) external view returns (bool) {
        LibStorage.EscrowData memory targetData = this.getEscrow(proofId);
        return targetData.status == 1 && targetData.buyer == operator && targetData.amount >= amount;
    }
}
