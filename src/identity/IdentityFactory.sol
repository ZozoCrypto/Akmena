// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/proxy/Clones.sol";

import "./Identity.sol";
import "./IIdentity.sol";
import "../registry/IRegistry.sol";

/// @title IdentityFactory
/// @notice Canonical factory for creating Akmena protocol identities.
contract IdentityFactory {

using Clones for address;

// ---------------------------------------------------------------------
// Errors
// ---------------------------------------------------------------------

error InvalidOwner();
error InvalidImplementation();
error InvalidRegistry();

// ---------------------------------------------------------------------
// State
// ---------------------------------------------------------------------

address public immutable implementation;

IRegistry public immutable registry;

uint256 public nextIdentityId;

// ---------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------

event IdentityCreated(
    uint256 indexed identityId,
    address indexed identity,
    address indexed owner,
    IIdentity.IdentityType identityType
);

// ---------------------------------------------------------------------
// Constructor
// ---------------------------------------------------------------------

constructor(
    address implementation_,
    address registry_
) {
    if (implementation_ == address(0))
        revert InvalidImplementation();

    if (registry_ == address(0))
        revert InvalidRegistry();

    implementation = implementation_;
    registry = IRegistry(registry_);
}

// ---------------------------------------------------------------------
// Identity Creation
// ---------------------------------------------------------------------

function createIdentity(
    IIdentity.IdentityType identityType,
    address owner,
    string calldata metadataURI
)
    external
    returns (address identity)
{
    if (owner == address(0))
        revert InvalidOwner();

    uint256 id = ++nextIdentityId;

    identity = implementation.clone();

    Identity(identity).initialize(
        id,
        owner,
        identityType,
        metadataURI
    );

    registry.registerIdentity(identity);

    emit IdentityCreated(
        id,
        identity,
        owner,
        identityType
    );
}

}
