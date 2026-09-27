// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {DelegationEngine} from "../../../src/authorization/DelegationEngine.sol";
import {IDelegationEngine} from "../../../src/authorization/IDelegationEngine.sol";
import {IIdentity} from "../../../src/identity/IIdentity.sol";
import {Identity} from "../../../src/identity/Identity.sol";

contract AttackAuthorizationBypassTest is Test {
    DelegationEngine internal delegation;
    Identity internal identity;

    address internal owner = address(0xAAAA);
    address internal attacker = address(0xBBBB);
    address internal delegate = address(0xCCCC);

    bytes32 internal constant WORKFLOW = keccak256("akmena.capability.workflow");

    function setUp() public {
        delegation = new DelegationEngine();

        identity = new Identity();
        identity.initialize(1, owner, IIdentity.IdentityType.Machine, "");
    }

    function test_AttackerCannotDelegateOnVictimIdentity() public {
        vm.prank(attacker);

        vm.expectRevert(IDelegationEngine.NotIdentityOwner.selector);

        delegation.setDelegate(address(identity), delegate, WORKFLOW, block.timestamp + 1 days, true);

        assertFalse(delegation.isDelegate(address(identity), delegate, WORKFLOW));
    }

    function test_AttackerCannotUseOwnerAddressAsIdentity() public {
        vm.prank(attacker);

        vm.expectRevert(IDelegationEngine.InvalidIdentity.selector);

        delegation.setDelegate(owner, delegate, WORKFLOW, block.timestamp + 1 days, true);
    }
}
