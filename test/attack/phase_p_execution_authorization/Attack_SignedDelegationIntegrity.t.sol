// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {DelegationEngine} from "../../../src/authorization/DelegationEngine.sol";
import {IDelegationEngine} from "../../../src/authorization/IDelegationEngine.sol";
import {IIdentity} from "../../../src/identity/IIdentity.sol";
import {Identity} from "../../../src/identity/Identity.sol";

contract DelegationEngineHarness is DelegationEngine {
    function exposedHashTypedDataV4(bytes32 structHash) external view returns (bytes32) {
        return _hashTypedDataV4(structHash);
    }
}

contract AttackSignedDelegationIntegrityTest is Test {
    DelegationEngineHarness internal delegation;

    uint256 internal constant OWNER_KEY = 0xA11CE;
    uint256 internal constant ATTACKER_KEY = 0xBEEF;

    address internal owner;
    address internal attacker;
    address internal delegate = address(0xBBBB);

    Identity internal identity;
    Identity internal otherIdentity;

    bytes32 internal constant WORKFLOW = keccak256("akmena.capability.workflow");

    bytes32 internal constant PAYMENT = keccak256("akmena.capability.payment");

    bytes32 internal constant TYPEHASH = keccak256(
        "Delegation(address identity,address delegate,bytes32 capability,bool status,uint256 nonce,uint256 deadline)"
    );

    function setUp() public {
        delegation = new DelegationEngineHarness();

        owner = vm.addr(OWNER_KEY);
        attacker = vm.addr(ATTACKER_KEY);

        identity = new Identity();

        identity.initialize(1, owner, IIdentity.IdentityType.Machine, "");

        otherIdentity = new Identity();

        otherIdentity.initialize(2, owner, IIdentity.IdentityType.Machine, "");
    }

    function _structHash(
        address identity_,
        address delegate_,
        bytes32 capability_,
        bool status_,
        uint256 nonce_,
        uint256 deadline_
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(TYPEHASH, identity_, delegate_, capability_, status_, nonce_, deadline_));
    }

    function _digest(
        address identity_,
        address delegate_,
        bytes32 capability_,
        bool status_,
        uint256 nonce_,
        uint256 deadline_
    ) internal view returns (bytes32) {
        return delegation.exposedHashTypedDataV4(
            _structHash(identity_, delegate_, capability_, status_, nonce_, deadline_)
        );
    }

    function _sign(
        address identity_,
        address delegate_,
        bytes32 capability_,
        bool status_,
        uint256 nonce_,
        uint256 deadline_,
        uint256 key
    ) internal view returns (bytes memory) {
        bytes32 digest = _digest(identity_, delegate_, capability_, status_, nonce_, deadline_);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);

        return abi.encodePacked(r, s, v);
    }

    function test_ValidOwnerSignatureCanSetDelegate() public {
        uint256 deadline = block.timestamp + 1 hours;

        bytes memory sig = _sign(address(identity), delegate, WORKFLOW, true, 0, deadline, OWNER_KEY);

        delegation.setDelegateTyped(address(identity), delegate, WORKFLOW, deadline, true, sig);

        assertTrue(delegation.isDelegate(address(identity), delegate, WORKFLOW));

        assertEq(delegation.nonces(address(identity)), 1);
    }

    function test_AttackerSignatureCannotAuthorizeOwnerIdentity() public {
        uint256 deadline = block.timestamp + 1 hours;

        bytes memory sig = _sign(address(identity), delegate, WORKFLOW, true, 0, deadline, ATTACKER_KEY);

        vm.expectRevert(IDelegationEngine.InvalidSignature.selector);

        delegation.setDelegateTyped(address(identity), delegate, WORKFLOW, deadline, true, sig);

        assertEq(delegation.nonces(address(identity)), 0);

        assertFalse(delegation.isDelegate(address(identity), delegate, WORKFLOW));
    }

    function test_ExpiredSignatureCannotExecute() public {
        uint256 deadline = block.timestamp + 1 hours;

        bytes memory sig = _sign(address(identity), delegate, WORKFLOW, true, 0, deadline, OWNER_KEY);

        vm.warp(deadline + 1);

        vm.expectRevert(IDelegationEngine.DelegationExpired.selector);

        delegation.setDelegateTyped(address(identity), delegate, WORKFLOW, deadline, true, sig);

        assertEq(delegation.nonces(address(identity)), 0);

        assertFalse(delegation.isDelegate(address(identity), delegate, WORKFLOW));
    }

    function test_ChangedDelegateInvalidatesSignature() public {
        uint256 deadline = block.timestamp + 1 hours;

        bytes memory sig = _sign(address(identity), delegate, WORKFLOW, true, 0, deadline, OWNER_KEY);

        address other = address(0xCCCC);

        vm.expectRevert(IDelegationEngine.InvalidSignature.selector);

        delegation.setDelegateTyped(address(identity), other, WORKFLOW, deadline, true, sig);

        assertEq(delegation.nonces(address(identity)), 0);

        assertFalse(delegation.isDelegate(address(identity), other, WORKFLOW));
    }

    function test_ChangedCapabilityInvalidatesSignature() public {
        uint256 deadline = block.timestamp + 1 hours;

        bytes memory sig = _sign(address(identity), delegate, WORKFLOW, true, 0, deadline, OWNER_KEY);

        vm.expectRevert(IDelegationEngine.InvalidSignature.selector);

        delegation.setDelegateTyped(address(identity), delegate, PAYMENT, deadline, true, sig);

        assertEq(delegation.nonces(address(identity)), 0);
    }

    function test_ChangedIdentityInvalidatesSignature() public {
        uint256 deadline = block.timestamp + 1 hours;

        bytes memory sig = _sign(address(identity), delegate, WORKFLOW, true, 0, deadline, OWNER_KEY);

        vm.expectRevert(IDelegationEngine.InvalidSignature.selector);

        delegation.setDelegateTyped(address(otherIdentity), delegate, WORKFLOW, deadline, true, sig);

        assertEq(delegation.nonces(address(otherIdentity)), 0);
    }

    function test_SignedDelegationCannotReplay() public {
        uint256 deadline = block.timestamp + 1 hours;

        bytes memory sig = _sign(address(identity), delegate, WORKFLOW, true, 0, deadline, OWNER_KEY);

        delegation.setDelegateTyped(address(identity), delegate, WORKFLOW, deadline, true, sig);

        assertEq(delegation.nonces(address(identity)), 1);

        vm.expectRevert(IDelegationEngine.InvalidSignature.selector);

        delegation.setDelegateTyped(address(identity), delegate, WORKFLOW, deadline, true, sig);

        assertEq(delegation.nonces(address(identity)), 1);
    }

    function test_NextNonceStartsAtZero() public view {
        assertEq(delegation.nonces(address(identity)), 0);
    }

    function test_DigestIsNonZero() public view {
        bytes32 digest = _digest(address(identity), delegate, WORKFLOW, true, 0, block.timestamp + 1 hours);

        assertTrue(digest != bytes32(0));
    }

    function test_OldOwnerCannotAuthorizeAfterOwnershipRotation() public {
        address newOwner = address(0xDDDD);

        vm.prank(owner);
        identity.transferOwnership(newOwner);

        uint256 deadline = block.timestamp + 1 hours;

        bytes memory oldOwnerSignature = _sign(address(identity), delegate, WORKFLOW, true, 0, deadline, OWNER_KEY);

        vm.expectRevert(IDelegationEngine.InvalidSignature.selector);

        delegation.setDelegateTyped(address(identity), delegate, WORKFLOW, deadline, true, oldOwnerSignature);

        assertEq(delegation.nonces(address(identity)), 0);
    }
}
