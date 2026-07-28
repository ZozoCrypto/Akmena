// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IRegistry} from "./IRegistry.sol";
import {IIdentity} from "../identity/IIdentity.sol";

/// @title Registry
/// @notice Canonical registry implementation for Akmena identities.
contract Registry is IRegistry {
    // ---------------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------------

    // Start IDs at 1 so that an ID of 0 represents an unregistered state.
    uint256 private _currentIdentityId = 1;

    mapping(uint256 => address) private _identitiesById;
    mapping(address => uint256) private _idsByIdentity;

    // ---------------------------------------------------------------------
    // Identity Allocation
    // ---------------------------------------------------------------------

    /// @inheritdoc IRegistry
    function allocateIdentityId() external override returns (uint256) {
        // NOTE: In production, this should be restricted to ONLY the IdentityFactory
        // via an access control modifier.
        uint256 allocatedId = _currentIdentityId;
        _currentIdentityId++;
        return allocatedId;
    }

    /// @inheritdoc IRegistry
    function nextIdentityId() external view override returns (uint256) {
        return _currentIdentityId;
    }

    // ---------------------------------------------------------------------
    // Registry Operations
    // ---------------------------------------------------------------------

    /// @inheritdoc IRegistry
    function registerIdentity(address identity) external override {
        if (_idsByIdentity[identity] != 0) {
            revert IdentityAlreadyRegistered();
        }

        // Fetch the ID directly from the deployed Identity contract
        uint256 id = IIdentity(identity).identityId();
        
        if (_identitiesById[id] != address(0)) {
            revert IdentityAlreadyRegistered();
        }

        _identitiesById[id] = identity;
        _idsByIdentity[identity] = id;

        emit IdentityRegistered(id, identity, IIdentity(identity).identityType());
    }

    /// @inheritdoc IRegistry
    function removeIdentity(uint256 id) external override {
        address identity = _identitiesById[id];
        if (identity == address(0)) {
            revert IdentityNotFound();
        }

        // Wipe from both mappings
        delete _identitiesById[id];
        delete _idsByIdentity[identity];

        emit IdentityRemoved(id, identity);
    }

    // ---------------------------------------------------------------------
    // Views
    // ---------------------------------------------------------------------

    /// @inheritdoc IRegistry
    function identityAddress(uint256 id) external view override returns (address) {
        return _identitiesById[id];
    }

    /// @inheritdoc IRegistry
    function identityId(address identity) external view override returns (uint256) {
        return _idsByIdentity[identity];
    }

    /// @inheritdoc IRegistry
    function exists(uint256 id) external view override returns (bool) {
        return _identitiesById[id] != address(0);
    }
}
