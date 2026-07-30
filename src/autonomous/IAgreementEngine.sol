// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {LibStorage} from "../storage/LibStorage.sol";

interface IAgreementEngine {
    event AgreementCreated(bytes32 indexed agreementId, address indexed partyA, address indexed partyB);
    event AgreementExecuted(bytes32 indexed agreementId);

    error InvalidAddress();
    error InvalidTerms();
    error AgreementAlreadyExists();
    error AgreementExpired();
    error UnauthorizedAccess();

    function createAgreement(bytes32 agreementId, address partyB, bytes32 termsHash, uint256 validUntil) external;
    function executeAgreement(bytes32 agreementId) external;
    function getAgreement(bytes32 agreementId) external view returns (LibStorage.AgreementData memory);
}
