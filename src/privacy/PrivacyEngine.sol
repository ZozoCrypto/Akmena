// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {LibTransientProof} from "../libraries/LibTransientProof.sol";

/// @title Akmena Privacy Engine
/// @notice Handles stealth commitments and private escrow releases for autonomous agents.
contract PrivacyEngine {
    mapping(bytes32 => bool) public commitments;
    mapping(bytes32 => bool) public nullifierHashes;

    event CommitmentDeposited(bytes32 indexed commitment, uint256 amount);
    event PrivateSettlementExecuted(bytes32 indexed nullifierHash, address indexed recipient, uint256 amount);

    error CommitmentAlreadyExists();
    error NullifierAlreadySpent();
    error InvalidCommitment();
    error TransferFailed();
    error InvalidAddress();

    /// @notice Lock value into a private escrow commitment
    function depositPrivateEscrow(bytes32 commitment) external payable {
        if (msg.value == 0) revert InvalidCommitment();
        if (commitments[commitment]) revert CommitmentAlreadyExists();

        commitments[commitment] = true;
        emit CommitmentDeposited(commitment, msg.value);
    }

    /// @notice Release private escrow to a stealth burner address via nullifier verification
    function executePrivateSettlement(
        bytes32 nullifierHash,
        bytes32 secret,
        uint256 amount,
        address payable stealthRecipient
    ) external {
        if (stealthRecipient == address(0)) revert InvalidAddress(); // Slither fix: zero-check
        if (nullifierHashes[nullifierHash]) revert NullifierAlreadySpent();
        
        bytes32 derivedCommitment = keccak256(abi.encodePacked(nullifierHash, secret, amount));
        if (!commitments[derivedCommitment]) revert InvalidCommitment();

        // 1. CEI Pattern: Invalidate nullifier immediately
        nullifierHashes[nullifierHash] = true;
        
        // 2. Erase the commitment leaf
        commitments[derivedCommitment] = false;

        // 3. Slither fix: Emit event BEFORE the external low-level call (Strict CEI)
        emit PrivateSettlementExecuted(nullifierHash, stealthRecipient, amount);

        // 4. Write EIP-1153 transient proof receipt
        LibTransientProof.setEscrowProof(uint256(nullifierHash), stealthRecipient, amount);

        // 5. Settle native asset
        (bool success, ) = stealthRecipient.call{value: amount}("");
        if (!success) revert TransferFailed();
    }
}
