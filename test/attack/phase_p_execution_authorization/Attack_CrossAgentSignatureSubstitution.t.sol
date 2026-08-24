// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract CrossAgentSignatureHarness is EIP712 {
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
            "AkmenaCrossAgent",
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

contract Attack_CrossAgentSignatureSubstitutionTest is Test {

    CrossAgentSignatureHarness internal auth;

    uint256 internal constant AGENT_A_KEY =
        0xA11CE;

    uint256 internal constant AGENT_B_KEY =
        0xBEEF;

    address internal agentA;
    address internal agentB;

    bytes32 internal constant PAYMENT_LANE =
        keccak256(
            "akmena.lane.payment"
        );

    function setUp()
        public
    {
        auth =
            new CrossAgentSignatureHarness();

        agentA =
            vm.addr(
                AGENT_A_KEY
            );

        agentB =
            vm.addr(
                AGENT_B_KEY
            );
    }

    function _authorization(
        address agent,
        uint256 nonce
    )
        internal
        view
        returns (
            CrossAgentSignatureHarness.Authorization memory
        )
    {
        return
            CrossAgentSignatureHarness.Authorization({
                agent: agent,
                lane: PAYMENT_LANE,
                nonce: nonce,
                deadline:
                    block.timestamp + 1 hours
            });
    }

    function _sign(
        uint256 privateKey,
        CrossAgentSignatureHarness.Authorization memory authorization
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
                privateKey,
                digest
            );

        return abi.encodePacked(
            r,
            s,
            v
        );
    }

    function test_AgentASignatureCannotExecuteAgentB()
        public
    {
        CrossAgentSignatureHarness.Authorization memory original =
            _authorization(
                agentA,
                1
            );

        bytes memory signature =
            _sign(
                AGENT_A_KEY,
                original
            );

        CrossAgentSignatureHarness.Authorization memory substituted =
            CrossAgentSignatureHarness.Authorization({
                agent: agentB,
                lane: original.lane,
                nonce: original.nonce,
                deadline: original.deadline
            });

        vm.expectRevert(
            CrossAgentSignatureHarness.InvalidSigner.selector
        );

        auth.execute(
            substituted,
            signature
        );
    }

    function test_AgentBSignatureCannotExecuteAgentA()
        public
    {
        CrossAgentSignatureHarness.Authorization memory original =
            _authorization(
                agentB,
                1
            );

        bytes memory signature =
            _sign(
                AGENT_B_KEY,
                original
            );

        CrossAgentSignatureHarness.Authorization memory substituted =
            CrossAgentSignatureHarness.Authorization({
                agent: agentA,
                lane: original.lane,
                nonce: original.nonce,
                deadline: original.deadline
            });

        vm.expectRevert(
            CrossAgentSignatureHarness.InvalidSigner.selector
        );

        auth.execute(
            substituted,
            signature
        );
    }

    function test_OriginalAgentASignatureStillWorks()
        public
    {
        CrossAgentSignatureHarness.Authorization memory authorization =
            _authorization(
                agentA,
                1
            );

        bytes memory signature =
            _sign(
                AGENT_A_KEY,
                authorization
            );

        auth.execute(
            authorization,
            signature
        );

        assertTrue(
            auth.used(
                agentA,
                PAYMENT_LANE,
                1
            )
        );
    }

    function test_OriginalAgentBSignatureStillWorks()
        public
    {
        CrossAgentSignatureHarness.Authorization memory authorization =
            _authorization(
                agentB,
                1
            );

        bytes memory signature =
            _sign(
                AGENT_B_KEY,
                authorization
            );

        auth.execute(
            authorization,
            signature
        );

        assertTrue(
            auth.used(
                agentB,
                PAYMENT_LANE,
                1
            )
        );
    }
}
