// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IIdentity} from "./IIdentity.sol";

/// @title IdentityClone
/// @notice The master implementation contract for all Akmena identities.
/// @dev Uses an initializer pattern because it will be deployed via ERC-1167 minimal proxies.
contract IdentityClone is IIdentity {
    bool private _initialized;
    uint256 private _id;
    IdentityType private _type;
    address private _owner;
    bool private _active;

    error AlreadyInitialized();
    error NotAuthorized();

    function initialize(uint256 id_, IdentityType type_, address owner_) external {
        if (_initialized) revert AlreadyInitialized();
        _initialized = true;
        _id = id_;
        _type = type_;
        _owner = owner_;
        _active = true;
    }

    function identityId() external view override returns (uint256) {
        return _id;
    }

    function identityType() external view override returns (IdentityType) {
        return _type;
    }

    function isActive() external view override returns (bool) {
        return _active;
    }

    function owner() external view override returns (address) {
        return _owner;
    }

    function metadataURI() external pure override returns (string memory) {
        return ""; // Can be expanded later for off-chain metadata links
    }

    function protocolVersion() external pure override returns (string memory) {
        return "1.0";
    }
}
