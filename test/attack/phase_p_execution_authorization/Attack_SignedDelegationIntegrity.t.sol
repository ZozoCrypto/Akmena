// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {DelegationEngine} from "../../../src/authorization/DelegationEngine.sol";

contract DelegationEngineHarness is DelegationEngine {
    function exposedHashTypedDataV4(
        bytes32 structHash
    ) external view returns (bytes32) {
        return _hashTypedDataV4(structHash);
    }
}

contract AttackSignedDelegationIntegrityTest is Test {
    DelegationEngineHarness internal delegation;

    uint256 internal constant OWNER_KEY =
        0xA11CE;

    uint256 internal constant ATTACKER_KEY =
        0xBEEF;

    address internal owner;
    address internal delegate =
        address(0xBBBB);

    address internal attacker;

    bytes32 internal constant TYPEHASH =
        keccak256(
            "SetDelegate(address delegate,bool status,uint256 nonce,uint256 deadline)"
        );

    function setUp() public {
        delegation = new DelegationEngineHarness();

        owner = vm.addr(OWNER_KEY);
        attacker = vm.addr(ATTACKER_KEY);
    }

    function _structHash(
        address delegate_,
        bool status,
        uint256 nonce,
        uint256 deadline
    )
        internal
        pure
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                TYPEHASH,
                delegate_,
                status,
                nonce,
                deadline
            )
        );
    }

    function _digest(
        address delegate_,
        bool status,
        uint256 nonce,
        uint256 deadline
    )
        internal
        returns (bytes32)
    {
        bytes32 structHash =
            _structHash(
                delegate_,
                status,
                nonce,
                deadline
            );

        return delegation.exposedHashTypedDataV4(
            structHash
        );
    }

    function _sign(
        address delegate_,
        bool status,
        uint256 nonce,
        uint256 deadline,
        uint256 key
    )
        internal
        returns (bytes memory)
    {
        bytes32 digest =
            _digest(
                delegate_,
                status,
                nonce,
                deadline
            );

        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(
                key,
                digest
            );

        return abi.encodePacked(
            r,
            s,
            v
        );
    }

    function test_ValidOwnerSignatureCanSetDelegate()
        public
    {
        uint256 deadline =
            block.timestamp + 1 hours;

        bytes memory sig =
            _sign(
                delegate,
                true,
                0,
                deadline,
                OWNER_KEY
            );

        delegation.setDelegateTyped(
            owner,
            delegate,
            true,
            deadline,
            sig
        );

        assertTrue(
            delegation.isDelegate(
                owner,
                delegate
            )
        );

        assertEq(
            delegation.nonces(owner),
            1
        );
    }

    function test_AttackerSignatureCannotAuthorizeOwner()
        public
    {
        uint256 deadline =
            block.timestamp + 1 hours;

        bytes memory sig =
            _sign(
                delegate,
                true,
                0,
                deadline,
                ATTACKER_KEY
            );

        vm.expectRevert();

        delegation.setDelegateTyped(
            owner,
            delegate,
            true,
            deadline,
            sig
        );

        assertEq(
            delegation.nonces(owner),
            0
        );

        assertFalse(
            delegation.isDelegate(
                owner,
                delegate
            )
        );
    }

    function test_ExpiredSignatureCannotExecute()
        public
    {
        uint256 deadline =
            block.timestamp;

        bytes memory sig =
            _sign(
                delegate,
                true,
                0,
                deadline,
                OWNER_KEY
            );

        vm.warp(
            deadline + 1
        );

        vm.expectRevert();

        delegation.setDelegateTyped(
            owner,
            delegate,
            true,
            deadline,
            sig
        );

        assertEq(
            delegation.nonces(owner),
            0
        );
    }

    function test_ChangedDelegateInvalidatesSignature()
        public
    {
        address other =
            address(0xCCCC);

        uint256 deadline =
            block.timestamp + 1 hours;

        bytes memory sig =
            _sign(
                delegate,
                true,
                0,
                deadline,
                OWNER_KEY
            );

        vm.expectRevert();

        delegation.setDelegateTyped(
            owner,
            other,
            true,
            deadline,
            sig
        );

        assertEq(
            delegation.nonces(owner),
            0
        );

        assertFalse(
            delegation.isDelegate(
                owner,
                other
            )
        );
    }

    function test_SignedDelegationCannotReplay()
        public
    {
        uint256 deadline =
            block.timestamp + 1 hours;

        bytes memory sig =
            _sign(
                delegate,
                true,
                0,
                deadline,
                OWNER_KEY
            );

        delegation.setDelegateTyped(
            owner,
            delegate,
            true,
            deadline,
            sig
        );

        assertEq(
            delegation.nonces(owner),
            1
        );

        vm.expectRevert();

        delegation.setDelegateTyped(
            owner,
            delegate,
            true,
            deadline,
            sig
        );

        assertEq(
            delegation.nonces(owner),
            1
        );
    }

    function test_NextNonceStartsAtZero()
        public
        view
    {
        assertEq(
            delegation.nonces(owner),
            0
        );
    }

    function test_DigestIsNonZero()
        public
    {
        bytes32 digest =
            _digest(
                delegate,
                true,
                0,
                block.timestamp + 1 hours
            );

        assertTrue(
            digest != bytes32(0)
        );
    }
}
