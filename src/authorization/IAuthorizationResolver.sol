// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IAuthorizationResolver {
    error InvalidRegistry();
    error InvalidCapabilityEngine();
    error InvalidDelegationEngine();
    error InvalidActor();
    error InvalidCapability();
    error IdentityNotFound();
    error IdentityInactive();
    error Unauthorized();

    function isAuthorized(uint256 identityId, address actor, bytes32 capability) external view returns (bool);

    function requireAuthorized(uint256 identityId, address actor, bytes32 capability) external view;
}
