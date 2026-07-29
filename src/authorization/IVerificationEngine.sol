// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IVerificationEngine {
    event IdentityVerified(address indexed identity, bool status);

    error InvalidAddress();

    function setVerification(address identity, bool status) external;
    function isVerified(address identity) external view returns (bool);
}
