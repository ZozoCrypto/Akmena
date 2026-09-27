// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {AuthorizationResolver} from "../../src/authorization/AuthorizationResolver.sol";
import {IAuthorizationResolver} from "../../src/authorization/IAuthorizationResolver.sol";
import {CapabilityEngine} from "../../src/authorization/CapabilityEngine.sol";
import {DelegationEngine} from "../../src/authorization/DelegationEngine.sol";
import {Identity} from "../../src/identity/Identity.sol";
import {IIdentity} from "../../src/identity/IIdentity.sol";
import {IdentityFactory} from "../../src/identity/IdentityFactory.sol";
import {Registry} from "../../src/registry/Registry.sol";

contract AuthorizationResolverTest is Test {
    Registry internal registry;
    IdentityFactory internal factory;
    Identity internal implementation;

    CapabilityEngine internal capabilities;
    DelegationEngine internal delegation;
    AuthorizationResolver internal resolver;

    address internal owner = address(0xA11CE);
    address internal delegate = address(0xB0B);
    address internal attacker = address(0xCAFE);

    bytes32 internal constant EXECUTE_ACTION = keccak256("EXECUTE_ACTION");

    bytes32 internal constant ADMIN = keccak256("ADMIN");

    address internal identity;
    uint256 internal identityId;

    function setUp() public {
        registry = new Registry();

        implementation = new Identity();

        factory = new IdentityFactory(address(implementation), address(registry));

        registry.bindIdentityFactory(address(factory));

        capabilities = new CapabilityEngine();
        delegation = new DelegationEngine();

        resolver = new AuthorizationResolver(address(registry), address(capabilities), address(delegation));

        vm.prank(owner);
        identity = factory.createIdentity(IIdentity.IdentityType.Machine, "");

        identityId = registry.identityId(identity);
    }

    function _grant(bytes32 capability) internal {
        vm.prank(owner);
        capabilities.grantCapability(identity, capability);
    }

    function _delegate(address who, bytes32 capability, uint256 deadline) internal {
        vm.prank(owner);

        delegation.setDelegate(identity, who, capability, deadline, true);
    }

    function test_OwnerAuthorizedOnlyWithCapability() public {
        assertFalse(resolver.isAuthorized(identityId, owner, EXECUTE_ACTION));

        _grant(EXECUTE_ACTION);

        assertTrue(resolver.isAuthorized(identityId, owner, EXECUTE_ACTION));
    }

    function test_DelegateAuthorizedOnlyWithCapabilityAndDelegation() public {
        _grant(EXECUTE_ACTION);

        assertFalse(resolver.isAuthorized(identityId, delegate, EXECUTE_ACTION));

        _delegate(delegate, EXECUTE_ACTION, block.timestamp + 1 hours);

        assertTrue(resolver.isAuthorized(identityId, delegate, EXECUTE_ACTION));
    }

    function test_WrongCapabilityRejected() public {
        _grant(EXECUTE_ACTION);

        _delegate(delegate, EXECUTE_ACTION, block.timestamp + 1 hours);

        assertFalse(resolver.isAuthorized(identityId, delegate, ADMIN));
    }

    function test_ThirdPartyRejected() public {
        _grant(EXECUTE_ACTION);

        _delegate(delegate, EXECUTE_ACTION, block.timestamp + 1 hours);

        assertFalse(resolver.isAuthorized(identityId, attacker, EXECUTE_ACTION));
    }

    function test_ExpiredDelegationRejected() public {
        _grant(EXECUTE_ACTION);

        _delegate(delegate, EXECUTE_ACTION, block.timestamp + 1 hours);

        vm.warp(block.timestamp + 1 hours);

        assertFalse(resolver.isAuthorized(identityId, delegate, EXECUTE_ACTION));
    }

    function test_OwnerCanUseCapabilityWithoutDelegation() public {
        _grant(EXECUTE_ACTION);

        assertTrue(resolver.isAuthorized(identityId, owner, EXECUTE_ACTION));
    }

    function test_CapabilityAloneDoesNotAuthorizeDelegate() public {
        _grant(EXECUTE_ACTION);

        assertFalse(resolver.isAuthorized(identityId, delegate, EXECUTE_ACTION));
    }

    function test_DelegationAloneDoesNotAuthorizeWithoutCapability() public {
        _delegate(delegate, EXECUTE_ACTION, block.timestamp + 1 hours);

        assertFalse(resolver.isAuthorized(identityId, delegate, EXECUTE_ACTION));
    }

    function test_UnknownIdentityRejected() public view {
        assertFalse(resolver.isAuthorized(identityId + 1000, owner, EXECUTE_ACTION));
    }

    function test_ZeroActorRejected() public view {
        assertFalse(resolver.isAuthorized(identityId, address(0), EXECUTE_ACTION));
    }

    function test_ZeroCapabilityRejected() public view {
        assertFalse(resolver.isAuthorized(identityId, owner, bytes32(0)));
    }

    function test_RequireAuthorizedRevertsForUnauthorized() public {
        vm.expectRevert(IAuthorizationResolver.Unauthorized.selector);

        resolver.requireAuthorized(identityId, attacker, EXECUTE_ACTION);
    }

    function test_RequireAuthorizedSucceedsForOwner() public {
        _grant(EXECUTE_ACTION);

        resolver.requireAuthorized(identityId, owner, EXECUTE_ACTION);
    }

    function test_RequireAuthorizedSucceedsForDelegate() public {
        _grant(EXECUTE_ACTION);

        _delegate(delegate, EXECUTE_ACTION, block.timestamp + 1 hours);

        resolver.requireAuthorized(identityId, delegate, EXECUTE_ACTION);
    }

    function test_OwnershipRotationRemovesOldOwnerAuthority() public {
        _grant(EXECUTE_ACTION);

        address newOwner = address(0xD00D);

        vm.prank(owner);
        Identity(identity).transferOwnership(newOwner);

        assertFalse(resolver.isAuthorized(identityId, owner, EXECUTE_ACTION));

        assertTrue(resolver.isAuthorized(identityId, newOwner, EXECUTE_ACTION));
    }
}
