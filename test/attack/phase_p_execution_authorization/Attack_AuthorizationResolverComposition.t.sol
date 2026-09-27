// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {AuthorizationResolver} from "../../../src/authorization/AuthorizationResolver.sol";
import {IAuthorizationResolver} from "../../../src/authorization/IAuthorizationResolver.sol";
import {CapabilityEngine} from "../../../src/authorization/CapabilityEngine.sol";
import {DelegationEngine} from "../../../src/authorization/DelegationEngine.sol";
import {Identity} from "../../../src/identity/Identity.sol";
import {IIdentity} from "../../../src/identity/IIdentity.sol";
import {IdentityFactory} from "../../../src/identity/IdentityFactory.sol";
import {Registry} from "../../../src/registry/Registry.sol";

contract AttackAuthorizationResolverCompositionTest is Test {
    Registry internal registry;
    IdentityFactory internal factory;
    Identity internal implementation;

    CapabilityEngine internal capabilities;
    DelegationEngine internal delegation;
    AuthorizationResolver internal resolver;

    address internal ownerA = address(0xA11CE);
    address internal ownerB = address(0xB0B);
    address internal delegate = address(0xDADA);
    address internal attacker = address(0xCAFE);

    bytes32 internal constant EXECUTE = keccak256("EXECUTE_ACTION");

    bytes32 internal constant ADMIN = keccak256("ADMIN");

    address internal identityA;
    address internal identityB;

    uint256 internal idA;
    uint256 internal idB;

    function setUp() public {
        registry = new Registry();
        implementation = new Identity();

        factory = new IdentityFactory(address(implementation), address(registry));

        registry.bindIdentityFactory(address(factory));

        capabilities = new CapabilityEngine();
        delegation = new DelegationEngine();

        resolver = new AuthorizationResolver(address(registry), address(capabilities), address(delegation));

        vm.prank(ownerA);
        identityA = factory.createIdentity(IIdentity.IdentityType.Machine, "");

        vm.prank(ownerB);
        identityB = factory.createIdentity(IIdentity.IdentityType.Organization, "");

        idA = registry.identityId(identityA);
        idB = registry.identityId(identityB);
    }

    function _grant(address identity, address owner, bytes32 capability) internal {
        vm.prank(owner);
        capabilities.grantCapability(identity, capability);
    }

    function _delegate(address identity, address owner, address delegate_, bytes32 capability) internal {
        vm.prank(owner);
        delegation.setDelegate(identity, delegate_, capability, block.timestamp + 1 days, true);
    }

    function test_AttackerCannotUseOwnerAddressAsIdentityId() public {
        _grant(identityA, ownerA, EXECUTE);

        uint256 forgedIdentityId = uint256(uint160(ownerA));

        assertFalse(resolver.isAuthorized(forgedIdentityId, attacker, EXECUTE));
    }

    function test_IdentityAAuthorizationCannotBeUsedForIdentityB() public {
        _grant(identityA, ownerA, EXECUTE);

        assertFalse(resolver.isAuthorized(idB, ownerA, EXECUTE));
    }

    function test_IdentityBCapabilityCannotAuthorizeIdentityA() public {
        _grant(identityB, ownerB, EXECUTE);

        assertFalse(resolver.isAuthorized(idA, ownerB, EXECUTE));
    }

    function test_CapabilitySubstitutionRejectedAcrossSameIdentity() public {
        _grant(identityA, ownerA, EXECUTE);

        assertTrue(resolver.isAuthorized(idA, ownerA, EXECUTE));

        assertFalse(resolver.isAuthorized(idA, ownerA, ADMIN));
    }

    function test_DelegateCannotCrossIdentityBoundary() public {
        _grant(identityA, ownerA, EXECUTE);

        _delegate(identityA, ownerA, delegate, EXECUTE);

        assertTrue(resolver.isAuthorized(idA, delegate, EXECUTE));

        assertFalse(resolver.isAuthorized(idB, delegate, EXECUTE));
    }

    function test_DelegateCannotEscalateCapability() public {
        _grant(identityA, ownerA, EXECUTE);

        _delegate(identityA, ownerA, delegate, EXECUTE);

        assertTrue(resolver.isAuthorized(idA, delegate, EXECUTE));

        assertFalse(resolver.isAuthorized(idA, delegate, ADMIN));
    }

    function test_InactiveIdentityCannotAuthorizeOwner() public {
        _grant(identityA, ownerA, EXECUTE);

        vm.prank(ownerA);
        Identity(identityA).deactivate();

        assertFalse(resolver.isAuthorized(idA, ownerA, EXECUTE));
    }

    function test_InactiveIdentityCannotAuthorizeDelegate() public {
        _grant(identityA, ownerA, EXECUTE);

        _delegate(identityA, ownerA, delegate, EXECUTE);

        vm.prank(ownerA);
        Identity(identityA).deactivate();

        assertFalse(resolver.isAuthorized(idA, delegate, EXECUTE));
    }

    function test_OldOwnerLosesAuthorityAfterRotation() public {
        _grant(identityA, ownerA, EXECUTE);

        address newOwner = address(0xEEEE);

        vm.prank(ownerA);
        Identity(identityA).transferOwnership(newOwner);

        assertFalse(resolver.isAuthorized(idA, ownerA, EXECUTE));

        assertTrue(resolver.isAuthorized(idA, newOwner, EXECUTE));
    }

    function test_DelegateDoesNotBecomeOwnerAfterOwnershipRotation() public {
        _grant(identityA, ownerA, EXECUTE);

        _delegate(identityA, ownerA, delegate, EXECUTE);

        address newOwner = address(0xEEEE);

        vm.prank(ownerA);
        Identity(identityA).transferOwnership(newOwner);

        assertFalse(resolver.isAuthorized(idA, ownerA, EXECUTE));

        assertTrue(resolver.isAuthorized(idA, delegate, EXECUTE));

        assertTrue(resolver.isAuthorized(idA, newOwner, EXECUTE));

        assertFalse(resolver.isAuthorized(idA, attacker, EXECUTE));
    }

    function test_UnknownIdentityCannotBeAuthorizedByCapabilityHolder() public {
        _grant(identityA, ownerA, EXECUTE);

        assertFalse(resolver.isAuthorized(idA + 9999, ownerA, EXECUTE));
    }

    function test_RequireAuthorizedRejectsInactiveIdentity() public {
        _grant(identityA, ownerA, EXECUTE);

        vm.prank(ownerA);
        Identity(identityA).deactivate();

        vm.expectRevert(IAuthorizationResolver.IdentityInactive.selector);

        resolver.requireAuthorized(idA, ownerA, EXECUTE);
    }

    function test_RequireAuthorizedRejectsCapabilitySubstitution() public {
        _grant(identityA, ownerA, EXECUTE);

        vm.expectRevert(IAuthorizationResolver.Unauthorized.selector);

        resolver.requireAuthorized(idA, ownerA, ADMIN);
    }
}
