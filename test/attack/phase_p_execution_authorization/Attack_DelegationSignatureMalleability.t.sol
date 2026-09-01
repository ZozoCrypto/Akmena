// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {DelegationEngine} from "../../../src/authorization/DelegationEngine.sol";

contract DelegationSignatureHarness is DelegationEngine {
    function exposedHashTypedDataV4(
        bytes32 structHash
    )
        external
        view
        returns (bytes32)
    {
        return _hashTypedDataV4(structHash);
    }
}

contract AttackDelegationSignatureMalleabilityTest is Test {
    DelegationSignatureHarness internal delegation;

    uint256 internal constant OWNER_KEY =
        0xA11CE;

    address internal owner;
    address internal delegate =
        address(0xBBBB);

    bytes32 internal constant TYPEHASH =
        keccak256(
            "SetDelegate(address delegate,bool status,uint256 nonce,uint256 deadline)"
        );

    function setUp() public {
        delegation =
            new DelegationSignatureHarness();

        owner =
            vm.addr(OWNER_KEY);
    }

    function _digest(
        address delegate_,
        bool status,
        uint256 nonce,
        uint256 deadline
    )
        internal
        view
        returns (bytes32)
    {
        bytes32 structHash =
            keccak256(
                abi.encode(
                    TYPEHASH,
                    delegate_,
                    status,
                    nonce,
                    deadline
                )
            );

        return
            delegation.exposedHashTypedDataV4(
                structHash
            );
    }

    function test_EmptySignatureRejected()
        public
    {
        uint256 deadline =
            block.timestamp + 1 hours;

        vm.expectRevert();

        delegation.setDelegateTyped(
            owner,
            delegate,
            true,
            deadline,
            hex""
        );

        assertEq(
            delegation.nonces(owner),
            0
        );
    }

    function test_ShortSignatureRejected()
        public
    {
        uint256 deadline =
            block.timestamp + 1 hours;

        vm.expectRevert();

        delegation.setDelegateTyped(
            owner,
            delegate,
            true,
            deadline,
            hex"12345678"
        );

        assertEq(
            delegation.nonces(owner),
            0
        );
    }

    function test_RandomGarbageSignatureRejected()
        public
    {
        uint256 deadline =
            block.timestamp + 1 hours;

        vm.expectRevert();

        delegation.setDelegateTyped(
            owner,
            delegate,
            true,
            deadline,
            hex"11223344556677889900aabbccddeeff"
        );

        assertEq(
            delegation.nonces(owner),
            0
        );
    }

    function test_UnsupportedVRejected()
        public
    {
        uint256 deadline =
            block.timestamp + 1 hours;

        bytes32 digest =
            _digest(
                delegate,
                true,
                0,
                deadline
            );

        (
            uint8 v,
            bytes32 r,
            bytes32 s
        ) =
            vm.sign(
                OWNER_KEY,
                digest
            );

        // Silence the unused canonical value while deliberately
        // replacing it with an unsupported ECDSA recovery value.
        v;

        bytes memory signature =
            abi.encodePacked(
                r,
                s,
                uint8(29)
            );

        vm.expectRevert();

        delegation.setDelegateTyped(
            owner,
            delegate,
            true,
            deadline,
            signature
        );

        assertEq(
            delegation.nonces(owner),
            0
        );
    }

    function test_WrongStructHashSignatureRejected()
        public
    {
        uint256 deadline =
            block.timestamp + 1 hours;

        bytes32 wrongStructHash =
            keccak256(
                "WRONG_STRUCT"
            );

        bytes32 wrongDigest =
            delegation.exposedHashTypedDataV4(
                wrongStructHash
            );

        (
            uint8 v,
            bytes32 r,
            bytes32 s
        ) =
            vm.sign(
                OWNER_KEY,
                wrongDigest
            );

        bytes memory signature =
            abi.encodePacked(
                r,
                s,
                v
            );

        vm.expectRevert();

        delegation.setDelegateTyped(
            owner,
            delegate,
            true,
            deadline,
            signature
        );

        assertEq(
            delegation.nonces(owner),
            0
        );
    }

    function test_SignatureForDifferentDelegateRejected()
        public
    {
        uint256 deadline =
            block.timestamp + 1 hours;

        bytes32 digest =
            _digest(
                delegate,
                true,
                0,
                deadline
            );

        (
            uint8 v,
            bytes32 r,
            bytes32 s
        ) =
            vm.sign(
                OWNER_KEY,
                digest
            );

        bytes memory signature =
            abi.encodePacked(
                r,
                s,
                v
            );

        address other =
            address(0xCCCC);

        vm.expectRevert();

        delegation.setDelegateTyped(
            owner,
            other,
            true,
            deadline,
            signature
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

    function test_SignatureForDifferentStatusRejected()
        public
    {
        uint256 deadline =
            block.timestamp + 1 hours;

        bytes32 digest =
            _digest(
                delegate,
                true,
                0,
                deadline
            );

        (
            uint8 v,
            bytes32 r,
            bytes32 s
        ) =
            vm.sign(
                OWNER_KEY,
                digest
            );

        bytes memory signature =
            abi.encodePacked(
                r,
                s,
                v
            );

        vm.expectRevert();

        delegation.setDelegateTyped(
            owner,
            delegate,
            false,
            deadline,
            signature
        );

        assertEq(
            delegation.nonces(owner),
            0
        );
    }
}
