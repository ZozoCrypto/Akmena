// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IAuthorizationResolver} from "./IAuthorizationResolver.sol";
import {ICapabilityEngine} from "./ICapabilityEngine.sol";
import {IDelegationEngine} from "./IDelegationEngine.sol";
import {IIdentity} from "../identity/IIdentity.sol";
import {IRegistry} from "../registry/IRegistry.sol";

contract AuthorizationResolver is IAuthorizationResolver {
    IRegistry public immutable registry;
    ICapabilityEngine public immutable capabilityEngine;
    IDelegationEngine public immutable delegationEngine;

    constructor(address registry_, address capabilityEngine_, address delegationEngine_) {
        if (registry_ == address(0) || registry_.code.length == 0) {
            revert InvalidRegistry();
        }

        if (capabilityEngine_ == address(0) || capabilityEngine_.code.length == 0) {
            revert InvalidCapabilityEngine();
        }

        if (delegationEngine_ == address(0) || delegationEngine_.code.length == 0) {
            revert InvalidDelegationEngine();
        }

        registry = IRegistry(registry_);
        capabilityEngine = ICapabilityEngine(capabilityEngine_);
        delegationEngine = IDelegationEngine(delegationEngine_);
    }

    function isAuthorized(uint256 identityId, address actor, bytes32 capability) external view override returns (bool) {
        if (actor == address(0) || capability == bytes32(0)) {
            return false;
        }

        address identity = registry.identityAddress(identityId);

        if (identity == address(0) || identity.code.length == 0) {
            return false;
        }

        IIdentity identityContract = IIdentity(identity);

        if (!identityContract.isActive()) {
            return false;
        }

        if (!capabilityEngine.hasCapability(identity, capability)) {
            return false;
        }

        if (identityContract.owner() == actor) {
            return true;
        }

        return delegationEngine.isDelegate(identity, actor, capability);
    }

    function requireAuthorized(uint256 identityId, address actor, bytes32 capability) external view override {
        if (actor == address(0)) {
            revert InvalidActor();
        }

        if (capability == bytes32(0)) {
            revert InvalidCapability();
        }

        address identity = registry.identityAddress(identityId);

        if (identity == address(0) || identity.code.length == 0) {
            revert IdentityNotFound();
        }

        if (!IIdentity(identity).isActive()) {
            revert IdentityInactive();
        }

        if (!capabilityEngine.hasCapability(identity, capability)) {
            revert Unauthorized();
        }

        if (IIdentity(identity).owner() == actor) {
            return;
        }

        if (delegationEngine.isDelegate(identity, actor, capability)) {
            return;
        }

        revert Unauthorized();
    }
}
