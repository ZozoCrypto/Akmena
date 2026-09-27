// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IEconomicCommitmentEngine} from "./IEconomicCommitmentEngine.sol";

import {IAgreementEngine} from "../autonomous/IAgreementEngine.sol";

import {IEscrowEngine} from "./IEscrowEngine.sol";

import {LibStorage} from "../storage/LibStorage.sol";

import {LibEconomicCommitmentStorage} from "../storage/LibEconomicCommitmentStorage.sol";

contract EconomicCommitmentEngine is IEconomicCommitmentEngine {
    bytes32 public constant ECONOMIC_TERMS_TYPEHASH =
        keccak256("AkmenaEconomicTermsV1(address payer,address payee,address asset,uint256 amount)");

    bytes32 public constant SETTLEMENT_TYPEHASH = keccak256("AkmenaEconomicSettlementV1(bytes32 commitmentId)");

    uint8 private constant ESCROW_ACTIVE = 1;
    uint8 private constant ESCROW_RELEASED = 2;
    uint8 private constant ESCROW_REFUNDED = 3;

    IAgreementEngine public immutable agreementEngine;
    IEscrowEngine public immutable escrowEngine;

    constructor(address agreementEngine_, address escrowEngine_) {
        if (
            agreementEngine_ == address(0) || agreementEngine_.code.length == 0 || escrowEngine_ == address(0)
                || escrowEngine_.code.length == 0
        ) {
            revert InvalidDependency();
        }

        agreementEngine = IAgreementEngine(agreementEngine_);

        escrowEngine = IEscrowEngine(escrowEngine_);
    }

    function computeEconomicTermsHash(address payer, address payee, address asset, uint256 amount)
        public
        pure
        override
        returns (bytes32)
    {
        return keccak256(abi.encode(ECONOMIC_TERMS_TYPEHASH, payer, payee, asset, amount));
    }

    function createCommitment(bytes32 agreementId, address asset_, uint256 amount) external override returns (bytes32) {
        if (asset_ == address(0) || asset_.code.length == 0) {
            revert InvalidAddress();
        }

        if (amount == 0) {
            revert InvalidAmount();
        }

        LibStorage.AgreementData memory agreementData = agreementEngine.getAgreement(agreementId);

        if (agreementData.partyA == address(0)) {
            revert AgreementNotFound();
        }

        if (!agreementData.isExecuted) {
            revert AgreementNotExecuted();
        }

        // Intentional timestamp boundary: economic commitments cannot use expired agreements.
        // forge-lint: disable-next-line(block-timestamp)
        if (block.timestamp > agreementData.validUntil) {
            revert AgreementExpired();
        }

        if (msg.sender != agreementData.partyA) {
            revert UnauthorizedCommitment();
        }

        LibEconomicCommitmentStorage.EconomicStorage storage es = LibEconomicCommitmentStorage.economic();

        if (es.commitmentByAgreement[agreementId] != bytes32(0)) {
            revert CommitmentAlreadyExists();
        }

        bytes32 expectedTermsHash = computeEconomicTermsHash(agreementData.partyA, agreementData.partyB, asset_, amount);

        if (agreementData.termsHash != expectedTermsHash) {
            revert EconomicTermsMismatch();
        }

        bytes32 commitmentId = keccak256(
            abi.encode(
                address(this),
                block.chainid,
                agreementId,
                agreementData.partyA,
                agreementData.partyB,
                asset_,
                amount,
                agreementData.termsHash
            )
        );

        if (commitmentId == bytes32(0)) {
            revert CommitmentAlreadyExists();
        }

        es.commitments[commitmentId] = LibEconomicCommitmentStorage.CommitmentData({
            commitmentId: commitmentId,
            agreementId: agreementId,
            escrowId: 0,
            payer: agreementData.partyA,
            payee: agreementData.partyB,
            asset: asset_,
            amount: amount,
            termsHash: agreementData.termsHash,
            status: IEconomicCommitmentEngine.CommitmentStatus.Pending
        });

        es.commitmentByAgreement[agreementId] = commitmentId;

        emit EconomicCommitmentCreated(
            commitmentId, agreementId, agreementData.partyA, agreementData.partyB, asset_, amount
        );

        return commitmentId;
    }

    function attachEscrow(bytes32 commitmentId, uint256 escrowId) external override {
        LibEconomicCommitmentStorage.EconomicStorage storage es = LibEconomicCommitmentStorage.economic();

        LibEconomicCommitmentStorage.CommitmentData storage commitment = es.commitments[commitmentId];

        if (commitment.commitmentId == bytes32(0)) {
            revert CommitmentNotFound();
        }

        if (commitment.status != IEconomicCommitmentEngine.CommitmentStatus.Pending) {
            revert InvalidCommitmentStatus();
        }

        if (msg.sender != commitment.payer) {
            revert UnauthorizedCommitment();
        }

        LibStorage.EscrowData memory escrowData = escrowEngine.getEscrow(escrowId);

        if (escrowData.status != ESCROW_ACTIVE) {
            revert EscrowStateMismatch();
        }

        if (escrowData.referenceId != commitmentId) {
            revert EscrowCommitmentMismatch();
        }

        if (
            escrowData.buyer != commitment.payer || escrowData.seller != commitment.payee
                || escrowData.asset != commitment.asset || escrowData.amount != commitment.amount
        ) {
            revert EscrowStateMismatch();
        }

        if (IERC20(commitment.asset).balanceOf(address(escrowEngine)) < commitment.amount) {
            revert EscrowNotFunded();
        }

        commitment.escrowId = escrowId;

        commitment.status = IEconomicCommitmentEngine.CommitmentStatus.EscrowAttached;

        emit EconomicEscrowAttached(commitmentId, escrowId);
    }

    /**
     * Finalize a commitment after its canonical escrow has been released.
     *
     * Settlement economics are derived exclusively from committed state;
     * callers cannot supply replacement payer, payee, asset, or amount data.
     */
    function finalizeSettlement(uint256 numericEscrowId, bytes32 commitmentId) external override {
        LibEconomicCommitmentStorage.EconomicStorage storage es = LibEconomicCommitmentStorage.economic();

        LibEconomicCommitmentStorage.CommitmentData storage commitment = es.commitments[commitmentId];

        if (commitment.commitmentId == bytes32(0)) {
            revert CommitmentNotFound();
        }

        if (commitment.status == IEconomicCommitmentEngine.CommitmentStatus.Settled) {
            return;
        }

        if (commitment.status != IEconomicCommitmentEngine.CommitmentStatus.EscrowAttached) {
            revert InvalidCommitmentStatus();
        }

        if (commitment.escrowId != numericEscrowId) {
            revert EscrowCommitmentMismatch();
        }

        LibStorage.EscrowData memory escrowData = escrowEngine.getEscrow(numericEscrowId);

        if (escrowData.status != ESCROW_RELEASED) {
            revert SettlementNotReleased();
        }

        if (
            escrowData.referenceId != commitmentId || escrowData.buyer != commitment.payer
                || escrowData.seller != commitment.payee || escrowData.asset != commitment.asset
                || escrowData.amount != commitment.amount
        ) {
            revert EscrowStateMismatch();
        }

        bytes32 settlementId = keccak256(abi.encode(SETTLEMENT_TYPEHASH, commitmentId));

        es.settlements[commitmentId] = LibEconomicCommitmentStorage.SettlementData({
            settlementId: settlementId,
            commitmentId: commitmentId,
            agreementId: commitment.agreementId,
            escrowId: commitment.escrowId,
            payer: commitment.payer,
            payee: commitment.payee,
            asset: commitment.asset,
            amount: commitment.amount,
            timestamp: block.timestamp
        });

        commitment.status = IEconomicCommitmentEngine.CommitmentStatus.Settled;

        emit EconomicSettlementRecorded(
            settlementId, commitmentId, commitment.escrowId, commitment.payer, commitment.payee, commitment.amount
        );
    }

    function finalizeRefund(bytes32 commitmentId) external override {
        LibEconomicCommitmentStorage.EconomicStorage storage es = LibEconomicCommitmentStorage.economic();

        LibEconomicCommitmentStorage.CommitmentData storage commitment = es.commitments[commitmentId];

        if (commitment.commitmentId == bytes32(0)) {
            revert CommitmentNotFound();
        }

        if (commitment.status != IEconomicCommitmentEngine.CommitmentStatus.EscrowAttached) {
            revert InvalidCommitmentStatus();
        }

        LibStorage.EscrowData memory escrowData = escrowEngine.getEscrow(commitment.escrowId);

        if (escrowData.status != ESCROW_REFUNDED) {
            revert InvalidCommitmentStatus();
        }

        if (
            escrowData.referenceId != commitmentId || escrowData.buyer != commitment.payer
                || escrowData.seller != commitment.payee || escrowData.asset != commitment.asset
                || escrowData.amount != commitment.amount
        ) {
            revert EscrowStateMismatch();
        }

        commitment.status = IEconomicCommitmentEngine.CommitmentStatus.Refunded;

        emit EconomicRefundFinalized(commitmentId, commitment.escrowId);
    }

    function getCommitment(bytes32 commitmentId)
        external
        view
        override
        returns (IEconomicCommitmentEngine.EconomicCommitment memory)
    {
        LibEconomicCommitmentStorage.CommitmentData storage commitment =
            LibEconomicCommitmentStorage.economic().commitments[commitmentId];

        if (commitment.commitmentId == bytes32(0)) {
            revert CommitmentNotFound();
        }

        return IEconomicCommitmentEngine.EconomicCommitment({
            commitmentId: commitment.commitmentId,
            agreementId: commitment.agreementId,
            escrowId: commitment.escrowId,
            payer: commitment.payer,
            payee: commitment.payee,
            asset: commitment.asset,
            amount: commitment.amount,
            termsHash: commitment.termsHash,
            status: commitment.status
        });
    }

    function getSettlement(bytes32 commitmentId)
        external
        view
        override
        returns (IEconomicCommitmentEngine.EconomicSettlement memory)
    {
        LibEconomicCommitmentStorage.SettlementData storage settlement =
            LibEconomicCommitmentStorage.economic().settlements[commitmentId];

        if (settlement.settlementId == bytes32(0)) {
            revert CommitmentNotFound();
        }

        return IEconomicCommitmentEngine.EconomicSettlement({
            settlementId: settlement.settlementId,
            commitmentId: settlement.commitmentId,
            agreementId: settlement.agreementId,
            escrowId: settlement.escrowId,
            payer: settlement.payer,
            payee: settlement.payee,
            asset: settlement.asset,
            amount: settlement.amount,
            timestamp: settlement.timestamp
        });
    }
}
