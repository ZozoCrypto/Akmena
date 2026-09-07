// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IEscrowEngine} from "./IEscrowEngine.sol";
import {LibStorage} from "../storage/LibStorage.sol";
import {ITransientProofVerifier} from "../authorization/ITransientProofVerifier.sol";

contract EscrowEngine is IEscrowEngine, ITransientProofVerifier {
    using SafeERC20 for IERC20;

    // EIP-1153 Transient Reentrancy Lock Slot
    bytes32 private constant REENTRANCY_LOCK_SLOT =
        keccak256("akmena.reentrancy.escrow");

    // Canonical AKM custody asset for this implementation.
    IERC20 public immutable asset;

    uint256 private _nextEscrowId = 1;

    // Actual amount of AKM currently locked across active escrows.
    uint256 public totalLocked;

    modifier nonReentrant() {
        bytes32 slot = REENTRANCY_LOCK_SLOT;

        assembly {
            if tload(slot) {
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

    constructor(address asset_) {
        if (asset_ == address(0)) {
            revert InvalidAddress();
        }

        asset = IERC20(asset_);
    }

    /// @notice Create and fund an escrow with real AKM custody.
    /// @dev The buyer must approve this contract for `amount`.
    function createEscrow(
        address buyer,
        address seller,
        uint256 amount
    ) external nonReentrant returns (uint256) {
        if (buyer == address(0) || seller == address(0)) {
            revert InvalidAddress();
        }

        if (amount == 0) {
            revert InvalidAmount();
        }

        // Escrow creation must be authorized by the asset owner.
        // ERC-20 allowance authorizes this contract as spender; it does
        // not authorize arbitrary callers to choose escrow parameters.
        if (msg.sender != buyer) {
            revert UnauthorizedAccess();
        }

        /*
         * The escrow cannot become ACTIVE until actual AKM has moved
         * into escrow custody.
         *
         * Using transferFrom(buyer, escrow, amount) preserves support
         * for delegated creation where the buyer has explicitly granted
         * allowance to the escrow contract.
         */
        asset.safeTransferFrom(
            buyer,
            address(this),
            amount
        );

        uint256 escrowId = _nextEscrowId++;

        LibStorage.EscrowData storage data =
            LibStorage.escrow().escrows[escrowId];

        data.buyer = buyer;
        data.seller = seller;
        data.amount = amount;
        data.asset = address(asset);
        data.status = 1; // Funded / Active

        totalLocked += amount;

        emit EscrowCreated(
            escrowId,
            buyer,
            seller,
            amount
        );

        return escrowId;
    }

    /// @notice Release escrowed AKM to the seller.
    function releaseEscrow(
        uint256 escrowId
    ) external nonReentrant {
        LibStorage.EscrowData storage data =
            LibStorage.escrow().escrows[escrowId];

        if (data.buyer == address(0)) {
            revert EscrowNotFound();
        }

        if (data.status != 1) {
            revert EscrowNotActive();
        }

        if (msg.sender != data.buyer) {
            revert UnauthorizedAccess();
        }

        uint256 amount = data.amount;

        if (asset.balanceOf(address(this)) < amount) {
            revert InsufficientEscrowBalance();
        }

        // Effects first; a failed token transfer reverts the entire tx.
        data.status = 2; // Released
        totalLocked -= amount;

        asset.safeTransfer(
            data.seller,
            amount
        );

        emit EscrowReleased(escrowId);
    }

    /// @notice Refund escrowed AKM to the original buyer.
    function refundEscrow(
        uint256 escrowId
    ) external nonReentrant {
        LibStorage.EscrowData storage data =
            LibStorage.escrow().escrows[escrowId];

        if (data.buyer == address(0)) {
            revert EscrowNotFound();
        }

        if (data.status != 1) {
            revert EscrowNotActive();
        }

        if (msg.sender != data.seller) {
            revert UnauthorizedAccess();
        }

        uint256 amount = data.amount;

        if (asset.balanceOf(address(this)) < amount) {
            revert InsufficientEscrowBalance();
        }

        // Effects first; a failed token transfer reverts the entire tx.
        data.status = 3; // Refunded
        totalLocked -= amount;

        asset.safeTransfer(
            data.buyer,
            amount
        );

        emit EscrowRefunded(escrowId);
    }

    function getEscrow(
        uint256 escrowId
    ) external view returns (LibStorage.EscrowData memory) {
        LibStorage.EscrowData storage data =
            LibStorage.escrow().escrows[escrowId];

        if (data.buyer == address(0)) {
            revert EscrowNotFound();
        }

        return data;
    }

    /// @notice Escrow proof is valid only while the exact funded escrow remains active.
    function verifyTransientProof(
        uint256 proofId,
        address operator,
        uint256 amount
    ) external view returns (bool) {
        LibStorage.EscrowData storage data =
            LibStorage.escrow().escrows[proofId];

        if (data.status != 1) {
            return false;
        }

        if (data.seller != operator) {
            return false;
        }

        if (data.amount != amount) {
            return false;
        }

        if (data.asset != address(asset)) {
            return false;
        }

        return true;
    }
}
