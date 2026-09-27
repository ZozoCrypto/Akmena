// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {DelegationEngine} from "../../../src/authorization/DelegationEngine.sol";
import {IDelegationEngine} from "../../../src/authorization/IDelegationEngine.sol";
import {IIdentity} from "../../../src/identity/IIdentity.sol";
import {Identity} from "../../../src/identity/Identity.sol";

contract AttackCanonicalDelegationScopeTest is Test {
    DelegationEngine internal delegation;

    uint256 internal ownerKey = 0xA11CE;
    address internal owner;

    address internal delegate = address(0xBBBB);
    address internal attacker = address(0xCCCC);

    Identity internal identity;

    bytes32 internal constant PAYMENT = keccak256("akmena.capability.payment");

    bytes32 internal constant WORKFLOW = keccak256("akmena.capability.workflow");

    function setUp() public {
        delegation = new DelegationEngine();

        owner = vm.addr(ownerKey);

        identity = new Identity();
        identity.initialize(1, owner, IIdentity.IdentityType.Machine, "");
    }

    function test_DelegateCannotSubstituteCapability() public {
        uint256 deadline = block.timestamp + 1 days;

        vm.prank(owner);
        delegation.setDelegate(address(identity), delegate, PAYMENT, deadline, true);

        assertTrue(delegation.isDelegate(address(identity), delegate, PAYMENT));

        assertFalse(delegation.isDelegate(address(identity), delegate, WORKFLOW));
    }

    function test_DelegationDoesNotGrantAuthorityToAnotherDelegate() public {
        uint256 deadline = block.timestamp + 1 days;

        vm.prank(owner);
        delegation.setDelegate(address(identity), delegate, WORKFLOW, deadline, true);

        assertTrue(delegation.isDelegate(address(identity), delegate, WORKFLOW));

        assertFalse(delegation.isDelegate(address(identity), attacker, WORKFLOW));
    }

    function test_ExpiredDelegateCannotBeUsedAsActiveAuthority() public {
        uint256 deadline = block.timestamp + 1 days;

        vm.prank(owner);
        delegation.setDelegate(address(identity), delegate, WORKFLOW, deadline, true);

        vm.warp(deadline + 1);

        assertFalse(delegation.isDelegate(address(identity), delegate, WORKFLOW));
    }

    function test_OwnerRotationChangesDirectDelegationAuthority() public {
        address newOwner = address(0xDDDD);

        vm.prank(owner);
        delegation.setDelegate(address(identity), delegate, WORKFLOW, block.timestamp + 1 days, true);

        vm.prank(owner);
        identity.transferOwnership(newOwner);

        vm.prank(owner);

        vm.expectRevert(IDelegationEngine.NotIdentityOwner.selector);

        delegation.setDelegate(address(identity), attacker, WORKFLOW, block.timestamp + 1 days, true);

        vm.prank(newOwner);

        delegation.setDelegate(address(identity), attacker, WORKFLOW, block.timestamp + 1 days, true);

        assertTrue(delegation.isDelegate(address(identity), attacker, WORKFLOW));
    }

    function test_IdentityCannotBeForgedByUsingOwnerAddress() public {
        vm.prank(owner);

        vm.expectRevert(IDelegationEngine.InvalidIdentity.selector);

        delegation.setDelegate(owner, delegate, WORKFLOW, block.timestamp + 1 days, true);
    }
}
