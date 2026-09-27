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
    bytes32 private constant REENTRANCY_LOCK_SLOT = keccak256("akmena.reentrancy.escrow");

    // Default/canonical AKM asset retained for backward-compatible entrypoints.
    IERC20 public immutable asset;

    uint256 private _nextEscrowId = 1;

    // Backward-compatible accounting for the default AKM asset.
    uint256 public totalLocked;

    // Exact active custody liability for every escrowed ERC20 asset.
    mapping(address => uint256) public totalLockedByAsset;

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

    /// @notice Create and fund an escrow using the default AKM asset.
    /// @dev The buyer must approve this contract for `amount`.
    function createEscrow(address buyer, address seller, uint256 amount) external nonReentrant returns (uint256) {
        return _createEscrow(buyer, seller, address(asset), amount, bytes32(0));
    }

    /// @notice Create and fund an escrow using the default AKM asset and reference.
    function createEscrow(address buyer, address seller, uint256 amount, bytes32 referenceId)
        external
        nonReentrant
        returns (uint256)
    {
        return _createEscrow(buyer, seller, address(asset), amount, referenceId);
    }

    /// @notice Create and fund an escrow for an explicit ERC20 asset.
    /// @dev The buyer must approve this contract for `amount`.
    function createEscrow(address buyer, address seller, address asset_, uint256 amount)
        external
        nonReentrant
        returns (uint256)
    {
        return _createEscrow(buyer, seller, asset_, amount, bytes32(0));
    }

    /// @notice Create and fund an escrow for an explicit ERC20 asset and reference.
    function createEscrow(address buyer, address seller, address asset_, uint256 amount, bytes32 referenceId)
        external
        nonReentrant
        returns (uint256)
    {
        return _createEscrow(buyer, seller, asset_, amount, referenceId);
    }

    function _createEscrow(address buyer, address seller, address asset_, uint256 amount, bytes32 referenceId)
        internal
        returns (uint256)
    {
        if (buyer == address(0) || seller == address(0)) {
            revert InvalidAddress();
        }

        if (asset_ == address(0) || asset_.code.length == 0) {
            revert InvalidAsset();
        }

        if (amount == 0) {
            revert InvalidAmount();
        }

        if (msg.sender != buyer) {
            revert UnauthorizedAccess();
        }

        LibStorage.EscrowStorage storage escrowStorage = LibStorage.escrow();

        if (referenceId != bytes32(0) && escrowStorage.referenceToEscrowId[referenceId] != 0) {
            revert EscrowReferenceAlreadyUsed();
        }

        IERC20 escrowAsset = IERC20(asset_);

        uint256 balanceBefore = escrowAsset.balanceOf(address(this));
        escrowAsset.safeTransferFrom(buyer, address(this), amount);
        uint256 balanceAfter = escrowAsset.balanceOf(address(this));

        if (balanceAfter < balanceBefore || balanceAfter - balanceBefore != amount) {
            revert EscrowFundingMismatch();
        }

        uint256 escrowId = _nextEscrowId++;

        LibStorage.EscrowData storage data = escrowStorage.escrows[escrowId];

        data.buyer = buyer;
        data.seller = seller;
        data.amount = amount;
        data.asset = asset_;
        data.status = 1;
        data.referenceId = referenceId;

        if (referenceId != bytes32(0)) {
            escrowStorage.referenceToEscrowId[referenceId] = escrowId;
        }

        totalLockedByAsset[asset_] += amount;

        // Preserve legacy totalLocked() semantics for the default AKM asset.
        if (asset_ == address(asset)) {
            totalLocked += amount;
        }

        emit EscrowCreated(escrowId, buyer, seller, amount);
        emit EscrowCreatedWithAsset(escrowId, buyer, seller, asset_, amount);

        return escrowId;
    }

    /// @notice Release escrowed AKM to the seller.
    function releaseEscrow(uint256 escrowId) external nonReentrant {
        LibStorage.EscrowData storage data = LibStorage.escrow().escrows[escrowId];

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
        IERC20 escrowAsset = IERC20(data.asset);

        if (escrowAsset.balanceOf(address(this)) < amount) {
            revert InsufficientEscrowBalance();
        }

        // Effects first; a failed token transfer reverts the entire tx.
        data.status = 2; // Released
        totalLockedByAsset[data.asset] -= amount;

        if (data.asset == address(asset)) {
            totalLocked -= amount;
        }

        escrowAsset.safeTransfer(data.seller, amount);

        emit EscrowReleased(escrowId);
    }

    /// @notice Refund escrowed AKM to the original buyer.
    function refundEscrow(uint256 escrowId) external nonReentrant {
        LibStorage.EscrowData storage data = LibStorage.escrow().escrows[escrowId];

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
        IERC20 escrowAsset = IERC20(data.asset);

        if (escrowAsset.balanceOf(address(this)) < amount) {
            revert InsufficientEscrowBalance();
        }

        // Effects first; a failed token transfer reverts the entire tx.
        data.status = 3; // Refunded
        totalLockedByAsset[data.asset] -= amount;

        if (data.asset == address(asset)) {
            totalLocked -= amount;
        }

        escrowAsset.safeTransfer(data.buyer, amount);

        emit EscrowRefunded(escrowId);
    }

    function getEscrow(uint256 escrowId) external view returns (LibStorage.EscrowData memory) {
        LibStorage.EscrowData storage data = LibStorage.escrow().escrows[escrowId];

        if (data.buyer == address(0)) {
            revert EscrowNotFound();
        }

        return data;
    }

    /// @notice Escrow proof is valid only while the exact funded escrow remains active.
    function verifyTransientProof(uint256 proofId, address operator, address asset_, uint256 amount)
        external
        view
        returns (bool)
    {
        LibStorage.EscrowData storage data = LibStorage.escrow().escrows[proofId];

        if (data.status != 1) {
            return false;
        }

        if (data.seller != operator) {
            return false;
        }

        if (data.amount != amount) {
            return false;
        }

        if (data.asset != asset_) {
            return false;
        }

        return true;
    }
}
