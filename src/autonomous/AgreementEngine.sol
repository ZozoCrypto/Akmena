// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IAgreementEngine} from "./IAgreementEngine.sol";
import {LibStorage} from "../storage/LibStorage.sol";

contract AgreementEngine is IAgreementEngine {
    function createAgreement(bytes32 agreementId, address partyB, bytes32 termsHash, uint256 validUntil) external override {
        if (partyB == address(0)) revert InvalidAddress();
        if (termsHash == bytes32(0)) revert InvalidTerms();

        LibStorage.AgreementStorage storage ds = LibStorage.agreement();
        
        if (ds.agreements[agreementId].partyA != address(0)) {
            revert AgreementAlreadyExists();
        }

        ds.agreements[agreementId] = LibStorage.AgreementData({
            partyA: msg.sender,
            partyB: partyB,
            termsHash: termsHash,
            validUntil: validUntil,
            isExecuted: false
        });

        emit AgreementCreated(agreementId, msg.sender, partyB);
    }

    function executeAgreement(bytes32 agreementId) external override {
        LibStorage.AgreementStorage storage ds = LibStorage.agreement();
        LibStorage.AgreementData storage agreementData = ds.agreements[agreementId];

        if (msg.sender != agreementData.partyB) revert UnauthorizedAccess();
        if (block.timestamp > agreementData.validUntil) revert AgreementExpired();
        if (agreementData.isExecuted) revert("AgreementAlreadyExecuted");

        agreementData.isExecuted = true;

        emit AgreementExecuted(agreementId);
    }

    function getAgreement(bytes32 agreementId) external view override returns (LibStorage.AgreementData memory) {
        return LibStorage.agreement().agreements[agreementId];
    }
}
