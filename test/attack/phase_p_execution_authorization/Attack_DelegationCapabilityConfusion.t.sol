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

    bytes32 internal constant PAYMENT =
        keccak256("akmena.capability.payment");

    bytes32 internal constant ADMIN =
        keccak256("akmena.capability.admin");

    function setUp() public {
        capabilities = new CapabilityEngine();
        delegation = new DelegationEngine();

        identity = new Identity();

        identity.initialize(
            1,
            owner,
            IIdentity.IdentityType.Machine,
            ""
        );
    }

    function test_DelegationDoesNotCreateCapability()
        public
    {
        vm.prank(owner);

        delegation.setDelegate(
            delegate,
            true
        );

        assertTrue(
            delegation.isDelegate(
                owner,
                delegate
            )
        );

        // Delegation alone must not mutate capability state.
        assertFalse(
            capabilities.hasCapability(
                address(identity),
                PAYMENT
            )
        );

        assertFalse(
            capabilities.hasCapability(
                delegate,
                PAYMENT
            )
        );
    }

    function test_DelegateCannotMutateOwnersCapabilityByDelegationAlone()
        public
    {
        vm.prank(owner);

        delegation.setDelegate(
            delegate,
            true
        );

        // The delegate may exist as a delegate,
        // but that relationship must not implicitly
        // authorize capability mutation.
        //
        // Delegation alone must NOT authorize capability mutation.
        vm.prank(delegate);

        vm.expectRevert(
            CapabilityEngine.UnauthorizedCapabilityMutation.selector
        );

        capabilities.grantCapability(
            address(identity),
            PAYMENT
        );

        assertFalse(
            capabilities.hasCapability(
                address(identity),
                PAYMENT
            )
        );
    }

    function test_OwnersCapabilityDoesNotAutomaticallyBecomeDelegatesCapability()
        public
    {
        vm.prank(owner);

        capabilities.grantCapability(
            address(identity),
            PAYMENT
        );

        vm.prank(owner);

        delegation.setDelegate(
            delegate,
            true
        );

        // Delegation does not copy capability state.
        assertTrue(
            capabilities.hasCapability(
                address(identity),
                PAYMENT
            )
        );

        assertFalse(
            capabilities.hasCapability(
                delegate,
                PAYMENT
            )
        );

        // The delegate also cannot mutate the owner's capability.
        vm.prank(delegate);

        vm.expectRevert(
            CapabilityEngine.UnauthorizedCapabilityMutation.selector
        );

        capabilities.revokeCapability(
            address(identity),
            PAYMENT
        );

        assertTrue(
            capabilities.hasCapability(
                address(identity),
                PAYMENT
            )
        );
    }

    function test_DelegationDoesNotGrantAdminCapability()
        public
    {
        vm.prank(owner);

        delegation.setDelegate(
            delegate,
            true
        );

        assertFalse(
            capabilities.hasCapability(
                delegate,
                ADMIN
            )
        );
    }

    function test_AttackerDelegationCannotAlterOwnersCapabilityState()
        public
    {
        vm.prank(attacker);

        delegation.setDelegate(
            owner,
            true
        );

        assertTrue(
            delegation.isDelegate(
                attacker,
                owner
            )
        );

        assertFalse(
            capabilities.hasCapability(
                owner,
                ADMIN
            )
        );
    }
}
