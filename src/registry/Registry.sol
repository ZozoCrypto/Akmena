// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IRegistry} from "./IRegistry.sol";
import {IIdentity} from "../identity/IIdentity.sol";

/// @title Registry
/// @notice Canonical registry implementation for Akmena identities.
contract Registry is IRegistry {
    error UnauthorizedFactory();
    error InvalidIdentityId();

    // The deployer is allowed to perform the one-time bootstrap binding.
    address public immutable factoryBinder;

    // Becomes permanently fixed after bindIdentityFactory().
    address public identityFactory;

    // ---------------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------------

    // Start IDs at 1 so that an ID of 0 represents an unregistered state.
    uint256 private _currentIdentityId = 1;

    mapping(uint256 => address) private _identitiesById;
    mapping(address => uint256) private _idsByIdentity;

    constructor() {
        factoryBinder = msg.sender;
    }

    // ---------------------------------------------------------------------
    // Factory Binding
    // ---------------------------------------------------------------------

    function bindIdentityFactory(address factory) external override {
        if (msg.sender != factoryBinder) revert UnauthorizedBinder();
        if (identityFactory != address(0)) revert FactoryAlreadyBound();
        if (factory == address(0) || factory.code.length == 0) {
            revert InvalidFactory();
        }

        identityFactory = factory;
    }

    // ---------------------------------------------------------------------
    // Identity Allocation
    // ---------------------------------------------------------------------

    /// @inheritdoc IRegistry
    function allocateIdentityId() external override returns (uint256) {
        if (identityFactory == address(0) || msg.sender != identityFactory) {
            revert UnauthorizedFactory();
        }

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
        if (identityFactory == address(0) || msg.sender != identityFactory) {
            revert UnauthorizedFactory();
        }
        if (identity == address(0) || identity.code.length == 0) {
            revert InvalidIdentity();
        }

        if (_idsByIdentity[identity] != 0) {
            revert IdentityAlreadyRegistered();
        }

        uint256 id = IIdentity(identity).identityId();

        if (id == 0) revert InvalidIdentityId();

        if (_identitiesById[id] != address(0)) {
            revert IdentityAlreadyRegistered();
        }

        _identitiesById[id] = identity;
        _idsByIdentity[identity] = id;

        emit IdentityRegistered(id, identity, IIdentity(identity).identityType());
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
