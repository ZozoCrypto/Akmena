// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract SignatureIntentReplayDebugHarness is EIP712 {
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

    constructor()
        EIP712("AkmenaSignatureReplay", "1")
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

        return _hashTypedDataV4(structHash);
    }
}

contract Attack_SignatureIntentReplayDebugTest is Test {

    SignatureIntentReplayDebugHarness internal auth;

    uint256 internal constant AGENT_KEY =
        0xA11CE;

    address internal agent;

    bytes32 internal constant PAYMENT_LANE =
        keccak256("akmena.lane.payment");

    function setUp()
        public
    {
        auth =
            new SignatureIntentReplayDebugHarness();

        agent =
            vm.addr(
                AGENT_KEY
            );
    }

    function _authorization(
        uint256 nonce
    )
        internal
        view
        returns (
            SignatureIntentReplayDebugHarness.Authorization memory
        )
    {
        return
            SignatureIntentReplayDebugHarness.Authorization({
                agent: agent,
                lane: PAYMENT_LANE,
                nonce: nonce,
                deadline: block.timestamp + 1 hours
            });
    }

    function test_DifferentNonceProducesDifferentDigest()
        public
    {
        SignatureIntentReplayDebugHarness.Authorization memory original =
            _authorization(1);

        SignatureIntentReplayDebugHarness.Authorization memory mutated =
            SignatureIntentReplayDebugHarness.Authorization({
                agent: original.agent,
                lane: original.lane,
                nonce: 2,
                deadline: original.deadline
            });

        bytes32 originalDigest =
            auth.hashAuthorization(original);

        bytes32 mutatedDigest =
            auth.hashAuthorization(mutated);

        emit log_named_uint(
            "original nonce",
            original.nonce
        );

        emit log_named_uint(
            "mutated nonce",
            mutated.nonce
        );

        emit log_bytes32(
            originalDigest
        );

        emit log_bytes32(
            mutatedDigest
        );

        assertEq(
            original.nonce,
            1
        );

        assertEq(
            mutated.nonce,
            2
        );

        assertTrue(
            originalDigest != mutatedDigest,
            "CRITICAL: different nonce produced identical digest"
        );
    }
}
