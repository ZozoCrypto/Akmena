// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {DelegationEngine} from "../../src/authorization/DelegationEngine.sol";
import {IDelegationEngine} from "../../src/authorization/IDelegationEngine.sol";
import {IIdentity} from "../../src/identity/IIdentity.sol";
import {Identity} from "../../src/identity/Identity.sol";

contract DelegationEngineTest is Test {
    DelegationEngine public engine;
    Identity public identity;

    uint256 internal ownerPrivateKey = 0xA11CE;
    address internal owner;

    address internal delegate = address(0x2222);
    address internal attacker = address(0xBEEF);

    bytes32 internal constant WORKFLOW_CAPABILITY = keccak256("akmena.capability.workflow");

    bytes32 internal constant PAYMENT_CAPABILITY = keccak256("akmena.capability.payment");

    function setUp() public {
        engine = new DelegationEngine();

        owner = vm.addr(ownerPrivateKey);

        identity = new Identity();
        identity.initialize(1, owner, IIdentity.IdentityType.Machine, "");
    }

    function test_OwnerCanCreateScopedDelegation() public {
        uint256 deadline = block.timestamp + 1 days;

        vm.prank(owner);
        engine.setDelegate(address(identity), delegate, WORKFLOW_CAPABILITY, deadline, true);

        assertTrue(engine.isDelegate(address(identity), delegate, WORKFLOW_CAPABILITY));

        assertFalse(engine.isDelegate(address(identity), delegate, PAYMENT_CAPABILITY));
    }

    function test_NonOwnerCannotCreateDelegation() public {
        vm.prank(attacker);

        vm.expectRevert(IDelegationEngine.NotIdentityOwner.selector);

        engine.setDelegate(address(identity), delegate, WORKFLOW_CAPABILITY, block.timestamp + 1 days, true);
    }

    function test_RevokedDelegationIsInactive() public {
        uint256 deadline = block.timestamp + 1 days;

        vm.prank(owner);
        engine.setDelegate(address(identity), delegate, WORKFLOW_CAPABILITY, deadline, true);

        assertTrue(engine.isDelegate(address(identity), delegate, WORKFLOW_CAPABILITY));

        vm.prank(owner);
        engine.setDelegate(address(identity), delegate, WORKFLOW_CAPABILITY, deadline, false);

        assertFalse(engine.isDelegate(address(identity), delegate, WORKFLOW_CAPABILITY));
    }

    function test_ExpiredDelegationIsInactive() public {
        uint256 deadline = block.timestamp + 1 days;

        vm.prank(owner);
        engine.setDelegate(address(identity), delegate, WORKFLOW_CAPABILITY, deadline, true);

        assertTrue(engine.isDelegate(address(identity), delegate, WORKFLOW_CAPABILITY));

        vm.warp(deadline + 1);

        assertFalse(engine.isDelegate(address(identity), delegate, WORKFLOW_CAPABILITY));
    }

    function test_RevertWhen_GrantingExpiredDelegation() public {
        uint256 deadline = block.timestamp;

        vm.prank(owner);

        vm.expectRevert(IDelegationEngine.DelegationExpired.selector);

        engine.setDelegate(address(identity), delegate, WORKFLOW_CAPABILITY, deadline, true);
    }

    function test_ZeroCapabilityRejected() public {
        vm.prank(owner);

        vm.expectRevert(IDelegationEngine.InvalidCapability.selector);

        engine.setDelegate(address(identity), delegate, bytes32(0), block.timestamp + 1 days, true);
    }

    function test_ZeroDelegateRejected() public {
        vm.prank(owner);

        vm.expectRevert(IDelegationEngine.InvalidAddress.selector);

        engine.setDelegate(address(identity), address(0), WORKFLOW_CAPABILITY, block.timestamp + 1 days, true);
    }

    function test_UnknownIdentityRejected() public {
        vm.prank(owner);

        vm.expectRevert(IDelegationEngine.InvalidIdentity.selector);

        engine.setDelegate(address(0x1234), delegate, WORKFLOW_CAPABILITY, block.timestamp + 1 days, true);
    }

    function test_OwnershipRotationInvalidatesOldSignedAuthority() public {
        address newOwner = address(0xDDDD);

        vm.prank(owner);
        identity.transferOwnership(newOwner);

        vm.prank(owner);

        vm.expectRevert(IDelegationEngine.NotIdentityOwner.selector);

        engine.setDelegate(address(identity), delegate, WORKFLOW_CAPABILITY, block.timestamp + 1 days, true);
    }
}
