// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {Registry} from "../../src/registry/Registry.sol";
import {IdentityClone} from "../../src/identity/IdentityClone.sol";
import {IdentityFactory} from "../../src/identity/IdentityFactory.sol";
import {IIdentity} from "../../src/identity/IIdentity.sol";

contract IdentityFactoryTest is Test {
    Registry public registry;
    IdentityClone public implementation;
    IdentityFactory public factory;

    function setUp() public {
        registry = new Registry();
        implementation = new IdentityClone();
        factory = new IdentityFactory(address(implementation), address(registry));
    }

    function test_CreateHumanIdentity() public {
        // Deploy a new clone via the factory
        address cloneAddress = factory.createIdentity(IIdentity.IdentityType.Human);
        IdentityClone clone = IdentityClone(cloneAddress);

        // Verify clone state
        assertEq(clone.owner(), address(this), "Owner should be the test contract");
        assertTrue(clone.isActive(), "Clone should be active");
        assertEq(uint256(clone.identityType()), uint256(IIdentity.IdentityType.Human), "Type should be Human");
        assertEq(clone.identityId(), 1, "First allocated ID should be 1");

        // Verify Registry linkage
        assertTrue(registry.exists(1), "Identity should exist in registry");
        assertEq(registry.identityAddress(1), cloneAddress, "Registry should point to clone");
        assertEq(registry.identityId(cloneAddress), 1, "Registry should map address to ID");
    }

    function test_CreateMachineIdentity() public {
        address cloneAddress = factory.createIdentity(IIdentity.IdentityType.Machine);
        IdentityClone clone = IdentityClone(cloneAddress);

        assertEq(uint256(clone.identityType()), uint256(IIdentity.IdentityType.Machine), "Type should be Machine");
    }

    function test_RevertWhen_ReinitializingClone() public {
        address cloneAddress = factory.createIdentity(IIdentity.IdentityType.Human);
        IdentityClone clone = IdentityClone(cloneAddress);

        // Attempting to initialize a second time must fail to prevent hijacking
        vm.expectRevert(IdentityClone.AlreadyInitialized.selector);
        clone.initialize(2, IIdentity.IdentityType.Machine, address(0xDEAD));
    }
}
