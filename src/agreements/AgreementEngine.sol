// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../interfaces/IAgreementEngine.sol";

/// @title Akmena Agreement Engine
/// @notice Registry and lifecycle manager for protocol agreements.
contract AgreementEngine is IAgreementEngine {
    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    error AgreementAlreadyExists();
    error AgreementNotFound();
    error InvalidTerms();
    error InvalidStatusTransition();

    // -------------------------------------------------------------------------
    // Storage
    // -------------------------------------------------------------------------

    mapping(bytes32 => Agreement) internal agreements;

    // -------------------------------------------------------------------------
    // Agreement Creation
    // -------------------------------------------------------------------------

    function propose(bytes32 agreementId, bytes32 proposerAgent, bytes32 counterpartyAgent, string calldata termsURI)
        external
    {
        if (exists(agreementId)) {
            revert AgreementAlreadyExists();
        }

        if (bytes(termsURI).length == 0) {
            revert InvalidTerms();
        }

        agreements[agreementId] = Agreement({
            id: agreementId,
            proposerAgent: proposerAgent,
            counterpartyAgent: counterpartyAgent,
            createdAt: uint64(block.timestamp),
            acceptedAt: 0,
            completedAt: 0,
            status: AgreementStatus.Proposed,
            termsURI: termsURI
        });

        emit AgreementProposed(agreementId, proposerAgent, counterpartyAgent, termsURI);
    }

    // -------------------------------------------------------------------------
    // Lifecycle
    // -------------------------------------------------------------------------

    function accept(bytes32 agreementId) external {
        if (!exists(agreementId)) {
            revert AgreementNotFound();
        }

        Agreement storage agreement = agreements[agreementId];

        if (agreement.status != AgreementStatus.Proposed) {
            revert InvalidStatusTransition();
        }

        agreement.status = AgreementStatus.Accepted;
        agreement.acceptedAt = uint64(block.timestamp);

        emit AgreementAccepted(agreementId);
    }

    function reject(bytes32 agreementId) external {
        if (!exists(agreementId)) {
            revert AgreementNotFound();
        }

        Agreement storage agreement = agreements[agreementId];

        if (agreement.status != AgreementStatus.Proposed) {
            revert InvalidStatusTransition();
        }

        agreement.status = AgreementStatus.Rejected;

        emit AgreementRejected(agreementId);
    }

    function complete(bytes32 agreementId) external {
        if (!exists(agreementId)) {
            revert AgreementNotFound();
        }

        Agreement storage agreement = agreements[agreementId];

        if (agreement.status != AgreementStatus.Accepted) {
            revert InvalidStatusTransition();
        }

        agreement.status = AgreementStatus.Completed;
        agreement.completedAt = uint64(block.timestamp);

        emit AgreementCompleted(agreementId);
    }

    // -------------------------------------------------------------------------
    // Views
    // -------------------------------------------------------------------------

    function exists(bytes32 agreementId) public view returns (bool) {
        return agreements[agreementId].createdAt != 0;
    }

    function getAgreement(bytes32 agreementId) external view returns (Agreement memory) {
        if (!exists(agreementId)) {
            revert AgreementNotFound();
        }

        return agreements[agreementId];
    }
}
