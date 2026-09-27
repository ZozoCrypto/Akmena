// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IRegistry} from "../registry/IRegistry.sol";
import {IIdentity} from "./IIdentity.sol";

interface IIdentityImplementation {
    function initialize(
        uint256 identityId_,
        address owner_,
        IIdentity.IdentityType identityType_,
        string calldata metadataURI_
    ) external;
}

/// @title IdentityFactory
/// @notice Deploys ERC-1167 minimal proxies for Akmena identities.
contract IdentityFactory {
    address public immutable implementation;
    IRegistry public immutable registry;

    event IdentityCreated(address indexed clone, uint256 indexed id, IIdentity.IdentityType indexed identityType);

    error CloneCreationFailed();
    error InvalidImplementation();
    error InvalidRegistry();

    constructor(address implementation_, address registry_) {
        if (implementation_ == address(0) || implementation_.code.length == 0) {
            revert InvalidImplementation();
        }

        if (registry_ == address(0) || registry_.code.length == 0) {
            revert InvalidRegistry();
        }

        implementation = implementation_;
        registry = IRegistry(registry_);
    }

    /// @notice Deploys a new identity clone and registers it canonically.
    function createIdentity(IIdentity.IdentityType identityType, string calldata metadataURI)
        external
        returns (address)
    {
        // 1. Allocate the canonical ID from the Registry.
        //    A later revert rolls this state change back atomically.
        uint256 newId = registry.allocateIdentityId();

        // 2. Deploy the ERC-1167 clone using memory-safe assembly.
        address clone = _clone(implementation);

        // 3. Initialize the proxy's complete canonical identity state.
        IIdentityImplementation(clone).initialize(newId, msg.sender, identityType, metadataURI);

        // 4. Register the fully initialized identity canonically.
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
