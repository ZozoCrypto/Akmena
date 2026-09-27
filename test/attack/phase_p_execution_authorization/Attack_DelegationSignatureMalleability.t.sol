// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {DelegationEngine} from "../../../src/authorization/DelegationEngine.sol";
import {IDelegationEngine} from "../../../src/authorization/IDelegationEngine.sol";
import {IIdentity} from "../../../src/identity/IIdentity.sol";
import {Identity} from "../../../src/identity/Identity.sol";

contract DelegationSignatureHarness is DelegationEngine {
    function exposedHashTypedDataV4(bytes32 structHash) external view returns (bytes32) {
        return _hashTypedDataV4(structHash);
    }
}

contract AttackDelegationSignatureMalleabilityTest is Test {
    DelegationSignatureHarness internal delegation;
    Identity internal identity;

    uint256 internal constant OWNER_KEY = 0xA11CE;

    address internal owner;
    address internal delegate = address(0xBBBB);
    address internal attacker = address(0xCCCC);

    bytes32 internal constant CAPABILITY = keccak256("akmena.capability.workflow");

    bytes32 internal constant OTHER_CAPABILITY = keccak256("akmena.capability.payment");

    bytes32 internal constant TYPEHASH = keccak256(
        "Delegation(address identity,address delegate,bytes32 capability,bool status,uint256 nonce,uint256 deadline)"
    );

    function setUp() public {
        delegation = new DelegationSignatureHarness();

        owner = vm.addr(OWNER_KEY);

        identity = new Identity();

        identity.initialize(1, owner, IIdentity.IdentityType.Machine, "");
    }

    function _digest(
        address identity_,
        address delegate_,
        bytes32 capability_,
        bool status_,
        uint256 nonce_,
        uint256 deadline_
    ) internal view returns (bytes32) {
        bytes32 structHash = keccak256(
            abi.encode(TYPEHASH, identity_, delegate_, capability_, status_, nonce_, deadline_)
        );

        return delegation.exposedHashTypedDataV4(structHash);
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

    function test_EmptySignatureRejected() public {
        uint256 deadline = block.timestamp + 1 hours;

        vm.expectRevert(IDelegationEngine.InvalidSignature.selector);

        delegation.setDelegateTyped(address(identity), delegate, CAPABILITY, deadline, true, hex"");

        assertEq(delegation.nonces(address(identity)), 0);

        assertFalse(delegation.isDelegate(address(identity), delegate, CAPABILITY));
    }

    function test_ShortSignatureRejected() public {
        uint256 deadline = block.timestamp + 1 hours;

        vm.expectRevert(IDelegationEngine.InvalidSignature.selector);

        delegation.setDelegateTyped(address(identity), delegate, CAPABILITY, deadline, true, hex"12345678");

        assertEq(delegation.nonces(address(identity)), 0);
    }

    function test_RandomGarbageSignatureRejected() public {
        uint256 deadline = block.timestamp + 1 hours;

        vm.expectRevert(IDelegationEngine.InvalidSignature.selector);

        delegation.setDelegateTyped(
            address(identity), delegate, CAPABILITY, deadline, true, hex"11223344556677889900aabbccddeeff"
        );

        assertEq(delegation.nonces(address(identity)), 0);
    }

    function test_UnsupportedVRejected() public {
        uint256 deadline = block.timestamp + 1 hours;

        bytes32 digest = _digest(address(identity), delegate, CAPABILITY, true, 0, deadline);

        (, bytes32 r, bytes32 s) = vm.sign(OWNER_KEY, digest);

        bytes memory signature = abi.encodePacked(r, s, uint8(29));

        vm.expectRevert(IDelegationEngine.InvalidSignature.selector);

        delegation.setDelegateTyped(address(identity), delegate, CAPABILITY, deadline, true, signature);

        assertEq(delegation.nonces(address(identity)), 0);
    }

    function test_WrongStructHashSignatureRejected() public {
        uint256 deadline = block.timestamp + 1 hours;

        bytes32 wrongStructHash = keccak256("WRONG_STRUCT");

        bytes32 wrongDigest = delegation.exposedHashTypedDataV4(wrongStructHash);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(OWNER_KEY, wrongDigest);

        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(IDelegationEngine.InvalidSignature.selector);

        delegation.setDelegateTyped(address(identity), delegate, CAPABILITY, deadline, true, signature);

        assertEq(delegation.nonces(address(identity)), 0);
    }

    function test_SignatureForDifferentDelegateRejected() public {
        uint256 deadline = block.timestamp + 1 hours;

        bytes memory signature = _sign(address(identity), delegate, CAPABILITY, true, 0, deadline, OWNER_KEY);

        address other = address(0xDDDD);

        vm.expectRevert(IDelegationEngine.InvalidSignature.selector);

        delegation.setDelegateTyped(address(identity), other, CAPABILITY, deadline, true, signature);

        assertEq(delegation.nonces(address(identity)), 0);

        assertFalse(delegation.isDelegate(address(identity), other, CAPABILITY));
    }

    function test_SignatureForDifferentStatusRejected() public {
        uint256 deadline = block.timestamp + 1 hours;

        bytes memory signature = _sign(address(identity), delegate, CAPABILITY, true, 0, deadline, OWNER_KEY);

        vm.expectRevert(IDelegationEngine.InvalidSignature.selector);

        delegation.setDelegateTyped(address(identity), delegate, CAPABILITY, deadline, false, signature);

        assertEq(delegation.nonces(address(identity)), 0);
    }

    function test_SignatureForDifferentCapabilityRejected() public {
        uint256 deadline = block.timestamp + 1 hours;

        bytes memory signature = _sign(address(identity), delegate, CAPABILITY, true, 0, deadline, OWNER_KEY);

        vm.expectRevert(IDelegationEngine.InvalidSignature.selector);

        delegation.setDelegateTyped(address(identity), delegate, OTHER_CAPABILITY, deadline, true, signature);

        assertEq(delegation.nonces(address(identity)), 0);
    }

    function test_SignatureForDifferentIdentityRejected() public {
        Identity otherIdentity = new Identity();

        otherIdentity.initialize(2, owner, IIdentity.IdentityType.Machine, "");

        uint256 deadline = block.timestamp + 1 hours;

        bytes memory signature = _sign(address(identity), delegate, CAPABILITY, true, 0, deadline, OWNER_KEY);

        vm.expectRevert(IDelegationEngine.InvalidSignature.selector);

        delegation.setDelegateTyped(address(otherIdentity), delegate, CAPABILITY, deadline, true, signature);

        assertEq(delegation.nonces(address(otherIdentity)), 0);
    }

    function test_SignatureFromAttackerRejected() public {
        uint256 deadline = block.timestamp + 1 hours;

        bytes memory signature =
            _sign(address(identity), delegate, CAPABILITY, true, 0, deadline, uint256(uint160(attacker)));

        vm.expectRevert(IDelegationEngine.InvalidSignature.selector);

        delegation.setDelegateTyped(address(identity), delegate, CAPABILITY, deadline, true, signature);

        assertEq(delegation.nonces(address(identity)), 0);

        assertFalse(delegation.isDelegate(address(identity), delegate, CAPABILITY));
    }
}
