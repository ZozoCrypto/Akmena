// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title Akmena Agreement Engine Interface
/// @notice Canonical interface for protocol agreements.
interface IAgreementEngine {
    // -------------------------------------------------------------------------
    // Enums
    // -------------------------------------------------------------------------

    enum AgreementStatus {
        Proposed,
        Accepted,
        Rejected,
        Completed,
        Cancelled
    }

    // -------------------------------------------------------------------------
    // Structs
    // -------------------------------------------------------------------------

    struct Agreement {
        bytes32 id;
        bytes32 proposerAgent;
        bytes32 counterpartyAgent;

        uint64 createdAt;
        uint64 acceptedAt;
        uint64 completedAt;

        AgreementStatus status;

        string termsURI;
    }

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    event AgreementProposed(
        bytes32 indexed agreementId, bytes32 indexed proposerAgent, bytes32 indexed counterpartyAgent, string termsURI
    );

    event AgreementAccepted(bytes32 indexed agreementId);

    event AgreementRejected(bytes32 indexed agreementId);

    event AgreementCompleted(bytes32 indexed agreementId);

    // -------------------------------------------------------------------------
    // Actions
    // -------------------------------------------------------------------------

    function propose(bytes32 agreementId, bytes32 proposerAgent, bytes32 counterpartyAgent, string calldata termsURI)
        external;

    function accept(bytes32 agreementId) external;

    function reject(bytes32 agreementId) external;

    function complete(bytes32 agreementId) external;

    // -------------------------------------------------------------------------
    // Views
    // -------------------------------------------------------------------------

    function exists(bytes32 agreementId) external view returns (bool);

    function getAgreement(bytes32 agreementId) external view returns (Agreement memory);
}
