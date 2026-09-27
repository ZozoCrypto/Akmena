// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {CapabilityEngine} from "../../../src/authorization/CapabilityEngine.sol";
import {DelegationEngine} from "../../../src/authorization/DelegationEngine.sol";
import {IIdentity} from "../../../src/identity/IIdentity.sol";
import {Identity} from "../../../src/identity/Identity.sol";

contract AttackDelegationCapabilityConfusionTest is Test {
    CapabilityEngine internal capabilities;
    DelegationEngine internal delegation;
    Identity internal identity;

    address internal owner = address(0xAAAA);
    address internal delegate = address(0xBBBB);
    address internal attacker = address(0xBEEF);

    bytes32 internal constant PAYMENT = keccak256("akmena.capability.payment");

    bytes32 internal constant ADMIN = keccak256("akmena.capability.admin");

    function setUp() public {
        capabilities = new CapabilityEngine();
        delegation = new DelegationEngine();

        identity = new Identity();
        identity.initialize(1, owner, IIdentity.IdentityType.Machine, "");
    }

    function test_DelegationDoesNotCreateCapability() public {
        vm.prank(owner);

        delegation.setDelegate(address(identity), delegate, PAYMENT, block.timestamp + 1 days, true);

        assertTrue(delegation.isDelegate(address(identity), delegate, PAYMENT));

        assertFalse(capabilities.hasCapability(address(identity), PAYMENT));
    }

    function test_DelegateCannotMutateOwnersCapabilityByDelegationAlone() public {
        vm.prank(owner);

        delegation.setDelegate(address(identity), delegate, PAYMENT, block.timestamp + 1 days, true);

        vm.prank(delegate);

        vm.expectRevert(CapabilityEngine.UnauthorizedCapabilityMutation.selector);

        capabilities.grantCapability(address(identity), PAYMENT);
    }

    function test_OwnerCapabilityDoesNotBecomeDelegateCapability() public {
        vm.prank(owner);

        capabilities.grantCapability(address(identity), PAYMENT);

        vm.prank(owner);

        delegation.setDelegate(address(identity), delegate, PAYMENT, block.timestamp + 1 days, true);

        assertTrue(capabilities.hasCapability(address(identity), PAYMENT));

        assertFalse(capabilities.hasCapability(delegate, PAYMENT));
    }

    function test_DelegationForPaymentDoesNotAuthorizeAdmin() public {
        vm.prank(owner);

        delegation.setDelegate(address(identity), delegate, PAYMENT, block.timestamp + 1 days, true);

        assertFalse(delegation.isDelegate(address(identity), delegate, ADMIN));
    }

    function test_AttackerCannotAlterVictimCapabilityStateThroughDelegation() public {
        vm.prank(attacker);

        vm.expectRevert();

        delegation.setDelegate(address(identity), attacker, ADMIN, block.timestamp + 1 days, true);

        assertFalse(capabilities.hasCapability(address(identity), ADMIN));
    }
}
