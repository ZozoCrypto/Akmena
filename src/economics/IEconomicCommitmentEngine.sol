// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IEconomicCommitmentEngine {
    enum CommitmentStatus {
        Pending,
        EscrowAttached,
        Settled,
        Refunded
    }

    struct EconomicCommitment {
        bytes32 commitmentId;
        bytes32 agreementId;
        uint256 escrowId;
        address payer;
        address payee;
        address asset;
        uint256 amount;
        bytes32 termsHash;
        CommitmentStatus status;
    }

    struct EconomicSettlement {
        bytes32 settlementId;
        bytes32 commitmentId;
        bytes32 agreementId;
        uint256 escrowId;
        address payer;
        address payee;
        address asset;
        uint256 amount;
        uint256 timestamp;
    }

    event EconomicCommitmentCreated(
        bytes32 indexed commitmentId,
        bytes32 indexed agreementId,
        address indexed payer,
        address payee,
        address asset,
        uint256 amount
    );

    event EconomicEscrowAttached(bytes32 indexed commitmentId, uint256 indexed escrowId);

    event EconomicSettlementRecorded(
        bytes32 indexed settlementId,
        bytes32 indexed commitmentId,
        uint256 indexed escrowId,
        address payer,
        address payee,
        uint256 amount
    );

    event EconomicRefundFinalized(bytes32 indexed commitmentId, uint256 indexed escrowId);

    error InvalidAddress();
    error InvalidAmount();
    error InvalidDependency();
    error AgreementNotFound();
    error AgreementNotExecuted();
    error AgreementExpired();
    error UnauthorizedCommitment();
    error EconomicTermsMismatch();
    error CommitmentAlreadyExists();
    error CommitmentNotFound();
    error InvalidCommitmentStatus();
    error EscrowCommitmentMismatch();
    error EscrowStateMismatch();
    error EscrowNotFunded();
    error SettlementAlreadyFinalized();
    error SettlementNotReleased();

    function computeEconomicTermsHash(address payer, address payee, address asset, uint256 amount)
        external
        pure
        returns (bytes32);

    function createCommitment(bytes32 agreementId, address asset, uint256 amount) external returns (bytes32);

    function attachEscrow(bytes32 commitmentId, uint256 escrowId) external;

    function finalizeSettlement(uint256 escrowId, bytes32 commitmentId) external;

    function finalizeRefund(bytes32 commitmentId) external;

    function getCommitment(bytes32 commitmentId) external view returns (EconomicCommitment memory);

    function getSettlement(bytes32 commitmentId) external view returns (EconomicSettlement memory);
}
