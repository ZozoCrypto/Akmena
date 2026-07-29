// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface ICapabilityEngine {
    event CapabilityGranted(address indexed identity, bytes32 indexed capability);
    event CapabilityRevoked(address indexed identity, bytes32 indexed capability);

    error InvalidIdentityAddress();
    error CapabilityAlreadyGranted();
    error CapabilityNotFound();

    function grantCapability(address identity, bytes32 capability) external;
    function revokeCapability(address identity, bytes32 capability) external;
    function hasCapability(address identity, bytes32 capability) external view returns (bool);
}
