// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ICapabilityEngine} from "./ICapabilityEngine.sol";
import {LibStorage} from "../storage/LibStorage.sol";

contract CapabilityEngine is ICapabilityEngine {
    function grantCapability(address identity, bytes32 capability) external override {
        if (identity == address(0)) revert InvalidIdentityAddress();
        
        LibStorage.AuthorizationStorage storage ds = LibStorage.authorization();
        
        if (ds.capabilities[identity][capability]) {
            revert CapabilityAlreadyGranted();
        }

        ds.capabilities[identity][capability] = true;
        emit CapabilityGranted(identity, capability);
    }

    function revokeCapability(address identity, bytes32 capability) external override {
        if (identity == address(0)) revert InvalidIdentityAddress();
        
        LibStorage.AuthorizationStorage storage ds = LibStorage.authorization();
        
        if (!ds.capabilities[identity][capability]) {
            revert CapabilityNotFound();
        }

        ds.capabilities[identity][capability] = false;
        emit CapabilityRevoked(identity, capability);
    }

    function hasCapability(address identity, bytes32 capability) external view override returns (bool) {
        LibStorage.AuthorizationStorage storage ds = LibStorage.authorization();
        return ds.capabilities[identity][capability];
    }
}
