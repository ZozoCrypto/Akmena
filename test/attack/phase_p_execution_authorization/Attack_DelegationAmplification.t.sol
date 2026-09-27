// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {DelegationEngine} from "../../../src/authorization/DelegationEngine.sol";
import {IDelegationEngine} from "../../../src/authorization/IDelegationEngine.sol";
import {IIdentity} from "../../../src/identity/IIdentity.sol";
import {Identity} from "../../../src/identity/Identity.sol";

contract AttackDelegationAmplificationTest is Test {
    DelegationEngine internal delegation;
    Identity internal identity;

    address internal owner = address(0xAAAA);
    address internal delegateB = address(0xBBBB);
    address internal delegateC = address(0xCCCC);
    address internal attacker = address(0xBEEF);

    bytes32 internal constant WORKFLOW = keccak256("akmena.capability.workflow");

    function setUp() public {
        delegation = new DelegationEngine();

        identity = new Identity();
        identity.initialize(1, owner, IIdentity.IdentityType.Machine, "");
    }

    function test_OwnerCanDelegateScopedCapability() public {
        vm.prank(owner);

        delegation.setDelegate(address(identity), delegateB, WORKFLOW, block.timestamp + 1 days, true);

        assertTrue(delegation.isDelegate(address(identity), delegateB, WORKFLOW));
    }

    function test_DelegationDoesNotImplicitlyAuthorizeThirdParty() public {
        vm.prank(owner);

        delegation.setDelegate(address(identity), delegateB, WORKFLOW, block.timestamp + 1 days, true);

        assertFalse(delegation.isDelegate(address(identity), delegateC, WORKFLOW));
    }

    function test_DelegatedIdentityCannotBeConfusedWithOwner() public {
        vm.prank(owner);

        delegation.setDelegate(address(identity), delegateB, WORKFLOW, block.timestamp + 1 days, true);

        assertTrue(delegation.isDelegate(address(identity), delegateB, WORKFLOW));

        assertFalse(delegation.isDelegate(delegateB, owner, WORKFLOW));
    }

    function test_AttackerCannotCreateDelegationForVictimIdentity() public {
        vm.prank(attacker);

        vm.expectRevert(IDelegationEngine.NotIdentityOwner.selector);

        delegation.setDelegate(address(identity), delegateC, WORKFLOW, block.timestamp + 1 days, true);

        assertFalse(delegation.isDelegate(address(identity), delegateC, WORKFLOW));
    }
}
