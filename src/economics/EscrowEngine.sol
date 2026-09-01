// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IEscrowEngine} from "./IEscrowEngine.sol";
import {LibStorage} from "../storage/LibStorage.sol";
import {ITransientProofVerifier} from "../authorization/ITransientProofVerifier.sol";

contract EscrowEngine is IEscrowEngine, ITransientProofVerifier {
    // EIP-1153 Transient Reentrancy Lock Slot
    bytes32 private constant REENTRANCY_LOCK_SLOT = keccak256("akmena.reentrancy.escrow");
    
    uint256 private _nextEscrowId = 1;

    modifier nonReentrant() {
        bytes32 slot = REENTRANCY_LOCK_SLOT;

        assembly {
            if tload(slot) {
                // Revert with generic ReentrancyGuard error
                mstore(0x00, 0x82b42900)
                revert(0x1c, 0x04)
            }
            tstore(slot, 1)
        }

        _;

        assembly {
            tstore(slot, 0)
        }
    }

    function createEscrow(address buyer, address seller, uint256 amount) external nonReentrant returns (uint256) {
        if (buyer == address(0) || seller == address(0)) revert InvalidAddress();
        if (amount == 0) revert InvalidAmount();
        
        uint256 escrowId = _nextEscrowId++;
        
        LibStorage.EscrowData storage data = LibStorage.escrow().escrows[escrowId];
        data.buyer = buyer;
        data.seller = seller;
        data.amount = amount;
        data.status = 1; // 1 = Funded / Active

        emit EscrowCreated(escrowId, buyer, seller, amount);
        return escrowId;
    }

    function releaseEscrow(uint256 escrowId) external nonReentrant {
        LibStorage.EscrowData storage data = LibStorage.escrow().escrows[escrowId];
        if (data.status != 1) revert EscrowNotActive();
        if (msg.sender != data.buyer) revert UnauthorizedAccess();

        data.status = 2; // 2 = Released (Terminal State)
        emit EscrowReleased(escrowId);
    }

    function refundEscrow(uint256 escrowId) external nonReentrant {
        LibStorage.EscrowData storage data = LibStorage.escrow().escrows[escrowId];
        if (data.status != 1) revert EscrowNotActive();
        if (msg.sender != data.seller) revert UnauthorizedAccess();

        data.status = 3; // 3 = Refunded (Terminal State)
        emit EscrowRefunded(escrowId);
    }

    function getEscrow(uint256 escrowId) external view returns (LibStorage.EscrowData memory) {
        LibStorage.EscrowData storage data = LibStorage.escrow().escrows[escrowId];
        if (data.buyer == address(0)) revert EscrowNotFound();
        return data;
    }

    function verifyTransientProof(uint256 proofId, address operator, uint256 amount) external view returns (bool) {
        LibStorage.EscrowData storage data = LibStorage.escrow().escrows[proofId];
        if (data.status != 1) return false;
        if (data.seller != operator) return false;
        if (data.amount != amount) return false;
        return true;
    }
}
