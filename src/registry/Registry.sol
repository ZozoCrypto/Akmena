// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./IRegistry.sol";
import "../identity/IIdentity.sol";

/// @title Registry
/// @notice Canonical participant registry for the Akmena Protocol.
/// @dev Maintains immutable protocol indexing of identities.
contract Registry is IRegistry {

// ---------------------------------------------------------------------
// Errors
// ---------------------------------------------------------------------

error NotFactory();
error AlreadyRegistered();
error UnknownIdentity();

// ---------------------------------------------------------------------
// Identity Record
// ---------------------------------------------------------------------

struct IdentityRecord {
    uint256 id;
    address identity;
    IIdentity.IdentityType identityType;
    bool active;
    uint64 createdBlock;
}

// ---------------------------------------------------------------------
// Storage
// ---------------------------------------------------------------------

address public immutable identityFactory;

// Satisfies the IRegistry missing nextIdentityId() error
uint256 public override nextIdentityId = 1;

mapping(uint256 => IdentityRecord) private records;
mapping(address => uint256) private identityIds;

// ---------------------------------------------------------------------
// Constructor
// ---------------------------------------------------------------------

constructor(address factory_) {
    identityFactory = factory_;
}

// ---------------------------------------------------------------------
// Registration
// ---------------------------------------------------------------------

function registerIdentity(address identity) external override {
    if (msg.sender != identityFactory) revert NotFactory();

    IIdentity id = IIdentity(identity);
    
    // Fixed shadowing: Changed variable name to _identityId
    uint256 _identityId = id.identityId();

    if (records[_identityId].identity != address(0)) revert AlreadyRegistered();

    records[_identityId] = IdentityRecord({
        id: _identityId,
        identity: identity,
        identityType: id.identityType(),
        active: true,
        createdBlock: uint64(block.number)
    });

    identityIds[identity] = _identityId;

    // Ensure the registry tracks the next available ID for the factory
    if (_identityId >= nextIdentityId) {
        nextIdentityId = _identityId + 1;
    }

    emit IdentityRegistered(_identityId, identity, id.identityType());
}

// ---------------------------------------------------------------------
// Queries
// ---------------------------------------------------------------------

function identityAddress(uint256 _identityId) external view override returns (address) {
    return records[_identityId].identity;
}

function identityId(address identity) external view override returns (uint256) {
    return identityIds[identity];
}

function exists(uint256 _identityId) external view override returns (bool) {
    return records[_identityId].identity != address(0);
}

// ---------------------------------------------------------------------
// Extended Queries
// ---------------------------------------------------------------------

function getRecord(uint256 _identityId) external view returns (IdentityRecord memory) {
    if (records[_identityId].identity == address(0)) revert UnknownIdentity();
    return records[_identityId];
}

}