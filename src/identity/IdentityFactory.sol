// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IRegistry} from "../registry/IRegistry.sol";
import {IIdentity} from "./IIdentity.sol";

interface IIdentityClone {
    function initialize(uint256 id_, IIdentity.IdentityType type_, address owner_) external;
}

/// @title IdentityFactory
/// @notice Deploys ERC-1167 minimal proxies for Akmena identities.
contract IdentityFactory {
    address public immutable implementation;
    IRegistry public immutable registry;

    event IdentityCreated(address indexed clone, uint256 indexed id, IIdentity.IdentityType indexed identityType);

    error CloneCreationFailed();

    constructor(address implementation_, address registry_) {
        implementation = implementation_;
        registry = IRegistry(registry_);
    }

    /// @notice Deploys a new identity clone and registers it canonically.
    function createIdentity(IIdentity.IdentityType identityType) external returns (address) {
        // 1. Deploy the ERC-1167 clone using memory-safe assembly
        address clone = _clone(implementation);

        // 2. Allocate the ID from the canonical Registry
        uint256 newId = registry.allocateIdentityId();
        
        // 3. Initialize the proxy's state
        IIdentityClone(clone).initialize(newId, identityType, msg.sender);
        
        // 4. Register the clone mapping in the Registry
        registry.registerIdentity(clone);

        emit IdentityCreated(clone, newId, identityType);
        return clone;
    }

    /// @dev Memory-Anchored EIP-1167 Minimal Proxy deployment
    function _clone(address impl) internal returns (address instance) {
        /// @solidity memory-safe-assembly
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(ptr, 0x14), shl(0x60, impl))
            mstore(add(ptr, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            instance := create(0, ptr, 0x37)
        }
        if (instance == address(0)) revert CloneCreationFailed();
    }
}
