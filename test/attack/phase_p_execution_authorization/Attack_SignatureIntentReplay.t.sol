// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract SignatureIntentReplayHarness is EIP712 {

    using ECDSA for bytes32;

    bytes32 public constant TYPEHASH =
        keccak256(
            "Authorization(address agent,bytes32 lane,uint256 nonce,uint256 deadline)"
        );

    struct Authorization {
        address agent;
        bytes32 lane;
        uint256 nonce;
        uint256 deadline;
    }

    mapping(
        address =>
        mapping(bytes32 =>
        mapping(uint256 => bool))
    )
    public used;

    error InvalidSigner();
    error Replay();
    error Expired();

    constructor()
        EIP712(
            "AkmenaSignatureReplay",
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
        bytes32 structHash =
            keccak256(
                abi.encode(
                    TYPEHASH,
                    authorization.agent,
                    authorization.lane,
                    authorization.nonce,
                    authorization.deadline
                )
            );

        return _hashTypedDataV4(
            structHash
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


contract Attack_SignatureIntentReplayTest is Test {

    SignatureIntentReplayHarness internal auth;

    uint256 internal constant AGENT_KEY =
        0xA11CE;

    address internal agent;

    bytes32 internal constant PAYMENT_LANE =
        keccak256(
            "akmena.lane.payment"
        );

    bytes32 internal constant ESCROW_LANE =
        keccak256(
            "akmena.lane.escrow"
        );

    function setUp()
        public
    {
        auth =
            new SignatureIntentReplayHarness();

        agent =
            vm.addr(
                AGENT_KEY
            );
    }

    function _authorization(
        bytes32 lane,
        uint256 nonce,
        uint256 lifetime
    )
        internal
        view
        returns (
            SignatureIntentReplayHarness.Authorization memory
        )
    {
        return
            SignatureIntentReplayHarness.Authorization({
                agent: agent,
                lane: lane,
                nonce: nonce,
                deadline:
                    block.timestamp +
                    lifetime
            });
    }

    function _sign(
        SignatureIntentReplayHarness.Authorization memory authorization
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

    function test_OriginalAuthorizationExecutes()
        public
    {
        SignatureIntentReplayHarness.Authorization memory original =
            _authorization(
                PAYMENT_LANE,
                1,
                1 hours
            );

        bytes memory signature =
            _sign(
                original
            );

        auth.execute(
            original,
            signature
        );

        assertTrue(
            auth.used(
                agent,
                PAYMENT_LANE,
                1
            )
        );
    }

    function test_SignatureCannotReplayWithDifferentLane()
        public
    {
        SignatureIntentReplayHarness.Authorization memory original =
            SignatureIntentReplayHarness.Authorization({
                agent: agent,
                lane: PAYMENT_LANE,
                nonce: 1,
                deadline: block.timestamp + 1 hours
            });

        SignatureIntentReplayHarness.Authorization memory mutated =
            SignatureIntentReplayHarness.Authorization({
                agent: agent,
                lane: ESCROW_LANE,
                nonce: 1,
                deadline: original.deadline
            });

        assertTrue(
            original.lane != mutated.lane,
            "lane mutation did not change field"
        );

        bytes memory signature =
            _sign(original);

        vm.expectRevert(
            SignatureIntentReplayHarness.InvalidSigner.selector
        );

        auth.execute(
            mutated,
            signature
        );
    }

    function test_SignatureCannotReplayWithDifferentNonce()
        public
    {
        SignatureIntentReplayHarness.Authorization memory original =
            SignatureIntentReplayHarness.Authorization({
                agent: agent,
                lane: PAYMENT_LANE,
                nonce: 1,
                deadline: block.timestamp + 1 hours
            });

        SignatureIntentReplayHarness.Authorization memory mutated =
            SignatureIntentReplayHarness.Authorization({
                agent: agent,
                lane: PAYMENT_LANE,
                nonce: 2,
                deadline: original.deadline
            });

        assertTrue(
            original.nonce != mutated.nonce,
            "nonce mutation did not change field"
        );

        bytes memory signature =
            _sign(original);

        vm.expectRevert(
            SignatureIntentReplayHarness.InvalidSigner.selector
        );

        auth.execute(
            mutated,
            signature
        );
    }

    function test_SignatureCannotReplayWithDifferentDeadline()
        public
    {
        SignatureIntentReplayHarness.Authorization memory original =
            SignatureIntentReplayHarness.Authorization({
                agent: agent,
                lane: PAYMENT_LANE,
                nonce: 1,
                deadline: block.timestamp + 1 hours
            });

        SignatureIntentReplayHarness.Authorization memory mutated =
            SignatureIntentReplayHarness.Authorization({
                agent: agent,
                lane: PAYMENT_LANE,
                nonce: 1,
                deadline: original.deadline + 1
            });

        assertTrue(
            original.deadline != mutated.deadline,
            "deadline mutation did not change field"
        );

        bytes memory signature =
            _sign(original);

        vm.expectRevert(
            SignatureIntentReplayHarness.InvalidSigner.selector
        );

        auth.execute(
            mutated,
            signature
        );
    }

    function test_DifferentIntentProducesDifferentDigest()
        public
    {
        SignatureIntentReplayHarness.Authorization memory original =
            SignatureIntentReplayHarness.Authorization({
                agent: agent,
                lane: PAYMENT_LANE,
                nonce: 1,
                deadline: block.timestamp + 1 hours
            });

        SignatureIntentReplayHarness.Authorization memory mutated =
            SignatureIntentReplayHarness.Authorization({
                agent: agent,
                lane: PAYMENT_LANE,
                nonce: 2,
                deadline: original.deadline
            });

        assertTrue(
            original.nonce != mutated.nonce,
            "digest differential intents unexpectedly equal"
        );

        bytes32 originalDigest =
            auth.hashAuthorization(original);

        bytes32 mutatedDigest =
            auth.hashAuthorization(mutated);

        assertTrue(
            originalDigest != mutatedDigest,
            "CRITICAL: different intents produced identical digest"
        );
    }
}
