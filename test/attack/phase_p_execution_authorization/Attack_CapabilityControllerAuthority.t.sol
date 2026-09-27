// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {CapabilityEngine} from "../../../src/authorization/CapabilityEngine.sol";

import {IIdentity} from "../../../src/identity/IIdentity.sol";

import {Identity} from "../../../src/identity/Identity.sol";

contract AttackCapabilityControllerAuthorityTest is Test {
    CapabilityEngine internal capabilities;
    Identity internal identity;

    address internal controller = address(0xAAAA);

    address internal attacker = address(0xBEEF);

    bytes32 internal constant EXECUTE = keccak256("EXECUTE_ACTION");

    function setUp() public {
        capabilities = new CapabilityEngine();

        identity = new Identity();

        identity.initialize(1, controller, IIdentity.IdentityType.Machine, "");
    }

    function test_ControllerCanGrantCapability() public {
        vm.prank(controller);

        capabilities.grantCapability(address(identity), EXECUTE);

        assertTrue(capabilities.hasCapability(address(identity), EXECUTE));
    }

    function test_ControllerCanRevokeCapability() public {
        vm.prank(controller);

        capabilities.grantCapability(address(identity), EXECUTE);

        vm.prank(controller);

        capabilities.revokeCapability(address(identity), EXECUTE);

        assertFalse(capabilities.hasCapability(address(identity), EXECUTE));
    }

    function test_AttackerCannotGrantCapability() public {
        vm.prank(attacker);

        vm.expectRevert();

        capabilities.grantCapability(address(identity), EXECUTE);

        assertFalse(capabilities.hasCapability(address(identity), EXECUTE));
    }

    function test_AttackerCannotRevokeCapability() public {
        vm.prank(controller);

        capabilities.grantCapability(address(identity), EXECUTE);

        vm.prank(attacker);

        vm.expectRevert();

        capabilities.revokeCapability(address(identity), EXECUTE);

        assertTrue(capabilities.hasCapability(address(identity), EXECUTE));
    }

    function test_OwnershipRotationMovesCapabilityAuthority() public {
        address newController = address(0xDDDD);

        vm.prank(controller);

        capabilities.grantCapability(address(identity), EXECUTE);

        vm.prank(controller);

        identity.transferOwnership(newController);

        vm.prank(controller);

        vm.expectRevert();

        capabilities.revokeCapability(address(identity), EXECUTE);

        vm.prank(newController);

        capabilities.revokeCapability(address(identity), EXECUTE);

        assertFalse(capabilities.hasCapability(address(identity), EXECUTE));
    }
}
