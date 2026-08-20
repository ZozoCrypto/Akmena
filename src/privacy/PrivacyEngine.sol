// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {LibTransientProof} from "../libraries/LibTransientProof.sol";

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

    function depositPrivateEscrow(bytes32 commitment) external payable {
        if (msg.value == 0) revert InvalidCommitment();
        if (commitments[commitment]) revert CommitmentAlreadyExists();

        commitments[commitment] = true;
        emit CommitmentDeposited(commitment, msg.value);
    }

    function executePrivateSettlement(
        bytes32 nullifierHash,
        bytes32 secret,
        uint256 amount,
        address payable stealthRecipient
    ) external {
        if (stealthRecipient == address(0)) revert InvalidAddress();
        if (nullifierHashes[nullifierHash]) revert NullifierAlreadySpent();
        
        bytes32 derivedCommitment = keccak256(abi.encodePacked(nullifierHash, secret, amount));
        if (!commitments[derivedCommitment]) revert InvalidCommitment();

        nullifierHashes[nullifierHash] = true;
        commitments[derivedCommitment] = false;

        emit PrivateSettlementExecuted(nullifierHash, stealthRecipient, amount);

        LibTransientProof.setEscrowProof(uint256(nullifierHash), stealthRecipient, amount);

        (bool success, ) = stealthRecipient.call{value: amount}("");
        if (!success) revert TransferFailed();
    }

    /// @notice Allows the PolicyBoundary to verify transient proofs written in this module's context
    function verifyTransientProof(uint256 proofId, address operator, uint256 amount) external view returns (bool) {
        return LibTransientProof.verifyEscrowProof(proofId, operator, amount);
    }
}
