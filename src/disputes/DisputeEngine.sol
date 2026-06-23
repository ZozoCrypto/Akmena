// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../interfaces/IDisputeEngine.sol";

contract DisputeEngine is IDisputeEngine {
    error DisputeAlreadyExists();
    error DisputeNotFound();
    error EmptyEvidence();
    error AlreadyFinalized();

    mapping(bytes32 => Dispute) internal disputes;

    function openDispute(bytes32 disputeId, bytes32 agreementId, string calldata evidenceURI) external {
        if (exists(disputeId)) {
            revert DisputeAlreadyExists();
        }

        if (bytes(evidenceURI).length == 0) {
            revert EmptyEvidence();
        }

        disputes[disputeId] = Dispute({
            id: disputeId,
            agreementId: agreementId,
            claimant: msg.sender,
            evidenceURI: evidenceURI,
            status: DisputeStatus.Open,
            createdAt: block.timestamp
        });

        emit DisputeOpened(disputeId, agreementId, msg.sender);
    }

    function resolveDispute(bytes32 disputeId) external {
        if (!exists(disputeId)) {
            revert DisputeNotFound();
        }

        Dispute storage dispute = disputes[disputeId];

        if (dispute.status != DisputeStatus.Open) {
            revert AlreadyFinalized();
        }

        dispute.status = DisputeStatus.Resolved;

        emit DisputeResolved(disputeId);
    }

    function rejectDispute(bytes32 disputeId) external {
        if (!exists(disputeId)) {
            revert DisputeNotFound();
        }

        Dispute storage dispute = disputes[disputeId];

        if (dispute.status != DisputeStatus.Open) {
            revert AlreadyFinalized();
        }

        dispute.status = DisputeStatus.Rejected;

        emit DisputeRejected(disputeId);
    }

    function exists(bytes32 disputeId) public view returns (bool) {
        return disputes[disputeId].claimant != address(0);
    }

    function getDispute(bytes32 disputeId) external view returns (Dispute memory) {
        if (!exists(disputeId)) {
            revert DisputeNotFound();
        }

        return disputes[disputeId];
    }
}
