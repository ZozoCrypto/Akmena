// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IDisputeEngine {
    enum DisputeStatus {
        Open,
        Resolved,
        Rejected
    }

    struct Dispute {
        bytes32 id;
        bytes32 agreementId;
        address claimant;
        string evidenceURI;
        DisputeStatus status;
        uint256 createdAt;
    }

    event DisputeOpened(bytes32 indexed disputeId, bytes32 indexed agreementId, address indexed claimant);

    event DisputeResolved(bytes32 indexed disputeId);

    event DisputeRejected(bytes32 indexed disputeId);

    function openDispute(bytes32 disputeId, bytes32 agreementId, string calldata evidenceURI) external;

    function resolveDispute(bytes32 disputeId) external;

    function rejectDispute(bytes32 disputeId) external;

    function exists(bytes32 disputeId) external view returns (bool);

    function getDispute(bytes32 disputeId) external view returns (Dispute memory);
}
