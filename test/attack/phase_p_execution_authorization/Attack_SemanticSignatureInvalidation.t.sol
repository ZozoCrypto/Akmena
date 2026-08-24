// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract SemanticSignatureHarness is EIP712 {
    using ECDSA for bytes32;

    bytes32 public constant TYPEHASH =
        keccak256(
            "SemanticIntent(address agent,bytes32 capability,address target,bytes4 selector,uint256 amount,bytes32 contextHash,bytes32 purposeHash,uint256 nonce,uint256 deadline)"
        );

    struct SemanticIntent {
        address agent;
        bytes32 capability;
        address target;
        bytes4 selector;
        uint256 amount;
        bytes32 contextHash;
        bytes32 purposeHash;
        uint256 nonce;
        uint256 deadline;
    }

    error InvalidSigner();
    error Replay();
    error Expired();

    mapping(address => mapping(uint256 => bool)) public used;

    constructor()
        EIP712("AkmenaSemanticIntent", "1")
    {}

    function hashIntent(
        SemanticIntent memory intent
    )
        public
        view
        returns (bytes32)
    {
        bytes32 structHash =
            keccak256(
                abi.encode(
                    TYPEHASH,
                    intent.agent,
                    intent.capability,
                    intent.target,
                    intent.selector,
                    intent.amount,
                    intent.contextHash,
                    intent.purposeHash,
                    intent.nonce,
                    intent.deadline
                )
            );

        return _hashTypedDataV4(structHash);
    }

    function execute(
        SemanticIntent calldata intent,
        bytes calldata signature
    )
        external
        returns (address signer)
    {
        if (block.timestamp > intent.deadline) {
            revert Expired();
        }

        if (used[intent.agent][intent.nonce]) {
            revert Replay();
        }

        signer =
            hashIntent(intent).recover(signature);

        if (signer != intent.agent) {
            revert InvalidSigner();
        }

        used[intent.agent][intent.nonce] = true;
    }
}


contract Attack_SemanticSignatureInvalidationTest is Test {

    SemanticSignatureHarness internal auth;

    uint256 internal constant AGENT_KEY =
        0xA11CE;

    address internal agent;

    bytes32 internal constant CAPABILITY =
        keccak256("akmena.capability.payment");

    address internal constant TARGET =
        address(0x1000);

    bytes4 internal constant SELECTOR =
        bytes4(
            keccak256("pay(address,uint256)")
        );

    bytes32 internal constant CONTEXT =
        keccak256(
            "invoice:88492|recipient:alice|account:12345"
        );

    bytes32 internal constant PURPOSE =
        keccak256(
            "purpose:aws-infrastructure"
        );

    function setUp()
        public
    {
        auth =
            new SemanticSignatureHarness();

        agent =
            vm.addr(AGENT_KEY);
    }

    function _intent(
        uint256 nonce
    )
        internal
        view
        returns (
            SemanticSignatureHarness.SemanticIntent memory
        )
    {
        return
            SemanticSignatureHarness.SemanticIntent({
                agent: agent,
                capability: CAPABILITY,
                target: TARGET,
                selector: SELECTOR,
                amount: 500 ether,
                contextHash: CONTEXT,
                purposeHash: PURPOSE,
                nonce: nonce,
                deadline: block.timestamp + 1 hours
            });
    }

    function _sign(
        SemanticSignatureHarness.SemanticIntent memory intent
    )
        internal
        view
        returns (bytes memory)
    {
        bytes32 digest =
            auth.hashIntent(intent);

        (
            uint8 v,
            bytes32 r,
            bytes32 s
        ) =
            vm.sign(
                AGENT_KEY,
                digest
            );

        return abi.encodePacked(r, s, v);
    }

    function test_ContextMutationInvalidatesOriginalSignature()
        public
    {
        SemanticSignatureHarness.SemanticIntent memory original =
            _intent(1);

        bytes memory signature =
            _sign(original);

        SemanticSignatureHarness.SemanticIntent memory mutated =
            SemanticSignatureHarness.SemanticIntent({
                agent: original.agent,
                capability: original.capability,
                target: original.target,
                selector: original.selector,
                amount: original.amount,
                contextHash: bytes32(uint256(0x2222)),
                purposeHash: original.purposeHash,
                nonce: original.nonce,
                deadline: original.deadline
            });

        assertTrue(
            auth.hashIntent(original) !=
            auth.hashIntent(mutated)
        );

        vm.expectRevert(
            SemanticSignatureHarness.InvalidSigner.selector
        );

        auth.execute(
            mutated,
            signature
        );

        assertFalse(
            auth.used(
                agent,
                1
            ),
            "mutated authorization must not consume nonce"
        );
    }

    function test_PurposeMutationInvalidatesOriginalSignature()
        public
    {
        SemanticSignatureHarness.SemanticIntent memory original =
            _intent(1);

        bytes memory signature =
            _sign(original);

        SemanticSignatureHarness.SemanticIntent memory mutated =
            SemanticSignatureHarness.SemanticIntent({
                agent: original.agent,
                capability: original.capability,
                target: original.target,
                selector: original.selector,
                amount: original.amount,
                contextHash: original.contextHash,
                purposeHash: bytes32(uint256(0x1111)),
                nonce: original.nonce,
                deadline: original.deadline
            });

        assertTrue(
            auth.hashIntent(original) !=
            auth.hashIntent(mutated)
        );

        vm.expectRevert(
            SemanticSignatureHarness.InvalidSigner.selector
        );

        auth.execute(
            mutated,
            signature
        );

        assertFalse(
            auth.used(
                agent,
                1
            )
        );
    }

    function test_ContextAndPurposeMutationTogetherInvalidatesSignature()
        public
    {
        SemanticSignatureHarness.SemanticIntent memory original =
            _intent(1);

        bytes memory signature =
            _sign(original);

        SemanticSignatureHarness.SemanticIntent memory mutated =
            SemanticSignatureHarness.SemanticIntent({
                agent: original.agent,
                capability: original.capability,
                target: original.target,
                selector: original.selector,
                amount: original.amount,
                contextHash: bytes32(uint256(0x3333)),
                purposeHash: bytes32(uint256(0x4444)),
                nonce: original.nonce,
                deadline: original.deadline
            });

        assertTrue(
            auth.hashIntent(original) !=
            auth.hashIntent(mutated)
        );

        vm.expectRevert(
            SemanticSignatureHarness.InvalidSigner.selector
        );

        auth.execute(
            mutated,
            signature
        );

        assertFalse(
            auth.used(
                agent,
                1
            )
        );
    }

    function test_OriginalSignatureStillExecutesOriginalIntent()
        public
    {
        SemanticSignatureHarness.SemanticIntent memory original =
            _intent(1);

        bytes memory signature =
            _sign(original);

        address signer =
            auth.execute(
                original,
                signature
            );

        assertEq(
            signer,
            agent
        );

        assertTrue(
            auth.used(
                agent,
                1
            )
        );
    }
}
