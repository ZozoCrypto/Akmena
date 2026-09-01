// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {DelegationEngine} from "../../../src/authorization/DelegationEngine.sol";

contract AttackDelegationAmplificationTest is Test {
    DelegationEngine internal delegation;

    address internal owner = address(0xAAAA);
    address internal delegateB = address(0xBBBB);
    address internal delegateC = address(0xCCCC);
    address internal attacker = address(0xBEEF);

    function setUp() public {
        delegation = new DelegationEngine();
    }

    function test_OwnerCanDelegateDirectly()
        public
    {
        vm.prank(owner);

        delegation.setDelegate(
            delegateB,
            true
        );

        assertTrue(
            delegation.isDelegate(
                owner,
                delegateB
            )
        );
    }

    function test_DelegationDoesNotImplicitlyAuthorizeThirdParty()
        public
    {
        vm.prank(owner);

        delegation.setDelegate(
            delegateB,
            true
        );

        // B being delegated by A must NOT automatically
        // make C a delegate of A.
        assertFalse(
            delegation.isDelegate(
                owner,
                delegateC
            )
        );
    }

    function test_DelegatedIdentityCannotBeConfusedWithOwner()
        public
    {
        vm.prank(owner);

        delegation.setDelegate(
            delegateB,
            true
        );

        assertTrue(
            delegation.isDelegate(
                owner,
                delegateB
            )
        );

        assertFalse(
            delegation.isDelegate(
                delegateB,
                owner
            )
        );
    }

    function test_AttackerCannotCreateDelegationForAnotherIdentity()
        public
    {
        vm.prank(attacker);

        // Direct delegation derives identity from msg.sender.
        delegation.setDelegate(
            delegateC,
            true
        );

        assertTrue(
            delegation.isDelegate(
                attacker,
                delegateC
            )
        );

        assertFalse(
            delegation.isDelegate(
                owner,
                delegateC
            )
        );
    }
}
