// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {Registry} from "../../src/registry/Registry.sol";
import {Identity} from "../../src/identity/Identity.sol";
import {IdentityFactory} from "../../src/identity/IdentityFactory.sol";
import {IIdentity} from "../../src/identity/IIdentity.sol";

contract FactoryMock {}

contract IdentityFactoryTest is Test {
    Registry public registry;
    Identity public implementation;
    IdentityFactory public factory;

    function setUp() public {
        registry = new Registry();
        implementation = new Identity();
        factory = new IdentityFactory(address(implementation), address(registry));
        registry.bindIdentityFactory(address(factory));
    }

    function test_CreateHumanIdentity() public {
        address cloneAddress = factory.createIdentity(IIdentity.IdentityType.Human, "ipfs://human");

        Identity clone = Identity(cloneAddress);

        assertEq(clone.owner(), address(this));
        assertTrue(clone.isActive());
        assertEq(uint256(clone.identityType()), uint256(IIdentity.IdentityType.Human));
        assertEq(clone.identityId(), 1);
        assertEq(clone.metadataURI(), "ipfs://human");
        assertEq(clone.protocolVersion(), "2.0.0");

        assertTrue(registry.exists(1));
        assertEq(registry.identityAddress(1), cloneAddress);
        assertEq(registry.identityId(cloneAddress), 1);
    }

    function test_CreateMachineIdentity() public {
        address cloneAddress = factory.createIdentity(IIdentity.IdentityType.Machine, "ipfs://machine");

        Identity clone = Identity(cloneAddress);

        assertEq(clone.owner(), address(this));
        assertTrue(clone.isActive());
        assertEq(uint256(clone.identityType()), uint256(IIdentity.IdentityType.Machine));
        assertEq(clone.identityId(), 1);
        assertEq(clone.metadataURI(), "ipfs://machine");
    }

    function test_CreateOrganizationIdentity() public {
        address cloneAddress = factory.createIdentity(IIdentity.IdentityType.Organization, "ipfs://org");

        Identity clone = Identity(cloneAddress);

        assertEq(uint256(clone.identityType()), uint256(IIdentity.IdentityType.Organization));
        assertEq(clone.identityId(), 1);
    }

    function test_CreateMultipleIdentitiesUseUniqueMonotonicIds() public {
        address first = factory.createIdentity(IIdentity.IdentityType.Human, "ipfs://1");
        address second = factory.createIdentity(IIdentity.IdentityType.Machine, "ipfs://2");
        address third = factory.createIdentity(IIdentity.IdentityType.Organization, "ipfs://3");

        assertEq(Identity(first).identityId(), 1);
        assertEq(Identity(second).identityId(), 2);
        assertEq(Identity(third).identityId(), 3);

        assertEq(registry.nextIdentityId(), 4);

        assertEq(registry.identityAddress(1), first);
        assertEq(registry.identityAddress(2), second);
        assertEq(registry.identityAddress(3), third);
    }

    function test_RevertWhen_ReinitializingClone() public {
        address cloneAddress = factory.createIdentity(IIdentity.IdentityType.Human, "ipfs://human");

        Identity clone = Identity(cloneAddress);

        vm.expectRevert();
        clone.initialize(2, address(0xDEAD), IIdentity.IdentityType.Machine, "ipfs://attacker");
    }

    function test_RevertWhen_ImplementationIsZero() public {
        vm.expectRevert(IdentityFactory.InvalidImplementation.selector);
        new IdentityFactory(address(0), address(registry));
    }

    function test_RevertWhen_ImplementationIsEOA() public {
        address eoa = address(0xBEEF);

        vm.expectRevert(IdentityFactory.InvalidImplementation.selector);
        new IdentityFactory(eoa, address(registry));
    }

    function test_RevertWhen_RegistryIsZero() public {
        vm.expectRevert(IdentityFactory.InvalidRegistry.selector);
        new IdentityFactory(address(implementation), address(0));
    }

    function test_RevertWhen_RegistryIsEOA() public {
        address eoa = address(0xCAFE);

        vm.expectRevert(IdentityFactory.InvalidRegistry.selector);
        new IdentityFactory(address(implementation), eoa);
    }
}
