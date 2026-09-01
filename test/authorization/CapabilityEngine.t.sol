// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {
    CapabilityEngine
} from "../../src/authorization/CapabilityEngine.sol";

import {
    ICapabilityEngine
} from "../../src/authorization/ICapabilityEngine.sol";

import {
    IIdentity
} from "../../src/identity/IIdentity.sol";

import {
    Identity
} from "../../src/identity/Identity.sol";


contract CapabilityEngineTest is Test {
    CapabilityEngine public engine;
    Identity public identity;

    address public controller =
        address(0xAAAA);

    bytes32 public constant EXECUTE_CAPABILITY =
        keccak256("EXECUTE_ACTION");


    function setUp() public {
        engine =
            new CapabilityEngine();

        identity =
            new Identity();

        identity.initialize(
            1,
            controller,
            IIdentity.IdentityType.Machine,
            ""
        );
    }


    function test_GrantCapability()
        public
    {
        vm.prank(controller);

        vm.expectEmit(
            true,
            true,
            true,
            true
        );

        emit ICapabilityEngine.CapabilityGranted(
            address(identity),
            EXECUTE_CAPABILITY
        );

        engine.grantCapability(
            address(identity),
            EXECUTE_CAPABILITY
        );

        assertTrue(
            engine.hasCapability(
                address(identity),
                EXECUTE_CAPABILITY
            ),
            "Capability should be granted"
        );
    }


    function test_RevertWhen_GrantingCapabilityTwice()
        public
    {
        vm.prank(controller);

        engine.grantCapability(
            address(identity),
            EXECUTE_CAPABILITY
        );

        vm.prank(controller);

        vm.expectRevert(
            ICapabilityEngine
                .CapabilityAlreadyGranted
                .selector
        );

        engine.grantCapability(
            address(identity),
            EXECUTE_CAPABILITY
        );
    }


    function test_RevokeCapability()
        public
    {
        vm.prank(controller);

        engine.grantCapability(
            address(identity),
            EXECUTE_CAPABILITY
        );

        vm.expectEmit(
            true,
            true,
            true,
            true
        );

        emit ICapabilityEngine.CapabilityRevoked(
            address(identity),
            EXECUTE_CAPABILITY
        );

        vm.prank(controller);

        engine.revokeCapability(
            address(identity),
            EXECUTE_CAPABILITY
        );

        assertFalse(
            engine.hasCapability(
                address(identity),
                EXECUTE_CAPABILITY
            ),
            "Capability should be revoked"
        );
    }


    function test_RevertWhen_RevokingNonExistentCapability()
        public
    {
        vm.prank(controller);

        vm.expectRevert(
            ICapabilityEngine
                .CapabilityNotFound
                .selector
        );

        engine.revokeCapability(
            address(identity),
            EXECUTE_CAPABILITY
        );
    }


    function test_RevertWhen_UsingZeroAddress()
        public
    {
        vm.expectRevert(
            ICapabilityEngine
                .InvalidIdentityAddress
                .selector
        );

        engine.grantCapability(
            address(0),
            EXECUTE_CAPABILITY
        );

        vm.expectRevert(
            ICapabilityEngine
                .InvalidIdentityAddress
                .selector
        );

        engine.revokeCapability(
            address(0),
            EXECUTE_CAPABILITY
        );
    }


    function test_NonControllerCannotMutateCapability()
        public
    {
        address attacker =
            address(0xBEEF);

        vm.prank(attacker);

        vm.expectRevert(
            CapabilityEngine
                .UnauthorizedCapabilityMutation
                .selector
        );

        engine.grantCapability(
            address(identity),
            EXECUTE_CAPABILITY
        );

        assertFalse(
            engine.hasCapability(
                address(identity),
                EXECUTE_CAPABILITY
            )
        );
    }


    function test_OwnershipRotationChangesCapabilityAuthority()
        public
    {
        address newController =
            address(0xDDDD);

        vm.prank(controller);

        engine.grantCapability(
            address(identity),
            EXECUTE_CAPABILITY
        );

        vm.prank(controller);

        identity.transferOwnership(
            newController
        );

        vm.prank(controller);

        vm.expectRevert(
            CapabilityEngine
                .UnauthorizedCapabilityMutation
                .selector
        );

        engine.revokeCapability(
            address(identity),
            EXECUTE_CAPABILITY
        );

        vm.prank(newController);

        engine.revokeCapability(
            address(identity),
            EXECUTE_CAPABILITY
        );

        assertFalse(
            engine.hasCapability(
                address(identity),
                EXECUTE_CAPABILITY
            )
        );
    }
}
