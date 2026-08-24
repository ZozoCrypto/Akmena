// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract SignatureIntegrityHarness is EIP712 {
    using ECDSA for bytes32;

    bytes32 internal constant TYPEHASH =
        keccak256(
            "Authorization(address agent,bytes32 lane,uint256 nonce,uint256 deadline)"
        );

    struct Authorization {
        address agent;
        bytes32 lane;
        uint256 nonce;
        uint256 deadline;
    }

    error InvalidSigner();
    error Replay();
    error Expired();

    mapping(
        address =>
        mapping(bytes32 =>
        mapping(uint256 => bool))
    )
    public used;

    constructor()
        EIP712(
            "AkmenaSignatureIntegrity",
            "1"
        )
    {}

    function hashAuthorization(
        Authorization memory authorization
    )
        public
        view
        returns (bytes32)
    {
        return _hashTypedDataV4(
            keccak256(
                abi.encode(
                    TYPEHASH,
                    authorization.agent,
                    authorization.lane,
                    authorization.nonce,
                    authorization.deadline
                )
            )
        );
    }

    function execute(
        Authorization calldata authorization,
        bytes calldata signature
    )
        external
    {
        if (
            block.timestamp >
            authorization.deadline
        ) {
            revert Expired();
        }

        if (
            used[
                authorization.agent
            ][
                authorization.lane
            ][
                authorization.nonce
            ]
        ) {
            revert Replay();
        }

        address signer =
            hashAuthorization(
                authorization
            ).recover(
                signature
            );

        if (
            signer !=
            authorization.agent
        ) {
            revert InvalidSigner();
        }

        used[
            authorization.agent
        ][
            authorization.lane
        ][
            authorization.nonce
        ] = true;
    }
}

contract Attack_SignatureIntegrityTest is Test {

    SignatureIntegrityHarness internal auth;

    uint256 internal constant AGENT_KEY =
        0xA11CE;

    address internal agent;

    bytes32 internal constant PAYMENT_LANE =
        keccak256(
            "akmena.lane.payment"
        );

    function setUp()
        public
    {
        auth =
            new SignatureIntegrityHarness();

        agent =
            vm.addr(
                AGENT_KEY
            );
    }

    function _authorization()
        internal
        view
        returns (
            SignatureIntegrityHarness.Authorization memory
        )
    {
        return
            SignatureIntegrityHarness.Authorization({
                agent: agent,
                lane: PAYMENT_LANE,
                nonce: 1,
                deadline:
                    block.timestamp + 1 hours
            });
    }

    function _sign(
        SignatureIntegrityHarness.Authorization memory authorization
    )
        internal
        view
        returns (bytes memory)
    {
        bytes32 digest =
            auth.hashAuthorization(
                authorization
            );

        (
            uint8 v,
            bytes32 r,
            bytes32 s
        ) =
            vm.sign(
                AGENT_KEY,
                digest
            );

        return abi.encodePacked(
            r,
            s,
            v
        );
    }

    function test_OriginalSignatureExecutes()
        public
    {
        SignatureIntegrityHarness.Authorization memory authorization =
            _authorization();

        auth.execute(
            authorization,
            _sign(authorization)
        );

        assertTrue(
            auth.used(
                agent,
                PAYMENT_LANE,
                1
            )
        );
    }

    function test_RMutationFails()
        public
    {
        SignatureIntegrityHarness.Authorization memory authorization =
            _authorization();

        bytes memory signature =
            _sign(authorization);

        signature[0] =
            bytes1(
                uint8(signature[0]) ^ 0x01
            );

        vm.expectRevert(
            ECDSA.ECDSAInvalidSignature.selector
        );

        auth.execute(
            authorization,
            signature
        );
    }

    function test_SMutationFails()
        public
    {
        SignatureIntegrityHarness.Authorization memory authorization =
            _authorization();

        bytes memory signature =
            _sign(authorization);

        signature[32] =
            bytes1(
                uint8(signature[32]) ^ 0x01
            );

        vm.expectRevert(
            SignatureIntegrityHarness.InvalidSigner.selector
        );

        auth.execute(
            authorization,
            signature
        );
    }

    function test_VMutationFails()
        public
    {
        SignatureIntegrityHarness.Authorization memory authorization =
            _authorization();

        bytes memory signature =
            _sign(authorization);

        signature[64] =
            bytes1(
                uint8(signature[64]) ^ 0x01
            );

        vm.expectRevert(
            ECDSA.ECDSAInvalidSignature.selector
        );

        auth.execute(
            authorization,
            signature
        );
    }

    function test_TruncatedSignatureFails()
        public
    {
        SignatureIntegrityHarness.Authorization memory authorization =
            _authorization();

        bytes memory signature =
            _sign(authorization);

        bytes memory truncated =
            new bytes(64);

        for (
            uint256 i = 0;
            i < 64;
            i++
        ) {
            truncated[i] =
                signature[i];
        }

        vm.expectRevert();

        auth.execute(
            authorization,
            truncated
        );
    }

    function test_ExpandedSignatureFails()
        public
    {
        SignatureIntegrityHarness.Authorization memory authorization =
            _authorization();

        bytes memory signature =
            _sign(authorization);

        bytes memory expanded =
            new bytes(65);

        for (
            uint256 i = 0;
            i < 65;
            i++
        ) {
            expanded[i] =
                signature[i];
        }

        expanded[64] =
            bytes1(
                uint8(expanded[64]) ^ 0x01
            );

        vm.expectRevert();

        auth.execute(
            authorization,
            expanded
        );
    }
}
