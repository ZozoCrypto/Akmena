// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IEscrowEngine} from "./IEscrowEngine.sol";
import {LibStorage} from "../storage/LibStorage.sol";

contract EscrowEngine is IEscrowEngine {
    function createEscrow(address buyer, address seller, uint256 amount) external override returns (uint256) {
        if (msg.sender != buyer) revert UnauthorizedAccess();
        if (buyer == address(0) || seller == address(0)) revert InvalidAddress();
        if (amount == 0) revert InvalidAmount();

        LibStorage.EscrowStorage storage ds = LibStorage.escrow();

        // Initialize ID at 1 for the first escrow
        if (ds.nextEscrowId == 0) ds.nextEscrowId = 1;

        uint256 currentId = ds.nextEscrowId;

        ds.escrows[currentId] = LibStorage.EscrowData({
            buyer: buyer,
            seller: seller,
            amount: amount,
            status: 1 // 1 = Funded
        });

        ds.nextEscrowId++;

        emit EscrowCreated(currentId, buyer, seller, amount);
        return currentId;
    }

    function releaseEscrow(uint256 escrowId) external override {
        LibStorage.EscrowStorage storage ds = LibStorage.escrow();
        LibStorage.EscrowData storage target = ds.escrows[escrowId];

        if (target.buyer == address(0)) revert EscrowNotFound();
        if (target.status != 1) revert EscrowNotActive();
        if (msg.sender != target.buyer) revert UnauthorizedAccess();

        target.status = 2; // 2 = Released

        emit EscrowReleased(escrowId);
    }

    function refundEscrow(uint256 escrowId) external override {
        LibStorage.EscrowStorage storage ds = LibStorage.escrow();
        LibStorage.EscrowData storage target = ds.escrows[escrowId];

        if (target.buyer == address(0)) revert EscrowNotFound();
        if (target.status != 1) revert EscrowNotActive();
        if (msg.sender != target.seller) revert UnauthorizedAccess();

        target.status = 3; // 3 = Refunded

        emit EscrowRefunded(escrowId);
    }

    function getEscrow(uint256 escrowId) external view override returns (LibStorage.EscrowData memory) {
        return LibStorage.escrow().escrows[escrowId];
    }
}
