// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {CapabilityEngine} from "../../../src/authorization/CapabilityEngine.sol";

import {IIdentity} from "../../../src/identity/IIdentity.sol";

import {Identity} from "../../../src/identity/Identity.sol";

contract AttackUnauthorizedCapabilityMutationTest is Test {
    CapabilityEngine internal capabilities;
    Identity internal identity;

    address internal victimController = address(0xAAAA);
    address internal attacker = address(0xBEEF);

    bytes32 internal constant EXECUTE = keccak256("EXECUTE_ACTION");

    function setUp() public {
        capabilities = new CapabilityEngine();

        identity = new Identity();

        identity.initialize(1, victimController, IIdentity.IdentityType.Machine, "");
    }

    function test_AttackerCannotGrantCapabilityToVictim() public {
        vm.prank(attacker);

        vm.expectRevert(CapabilityEngine.UnauthorizedCapabilityMutation.selector);

        capabilities.grantCapability(address(identity), EXECUTE);

        assertFalse(capabilities.hasCapability(address(identity), EXECUTE));
    }

    function test_AttackerCannotRevokeVictimCapability() public {
        vm.prank(victimController);

        capabilities.grantCapability(address(identity), EXECUTE);

        vm.prank(attacker);

        vm.expectRevert(CapabilityEngine.UnauthorizedCapabilityMutation.selector);

        capabilities.revokeCapability(address(identity), EXECUTE);

        assertTrue(capabilities.hasCapability(address(identity), EXECUTE));
    }
}
