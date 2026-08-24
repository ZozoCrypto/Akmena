// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

/*
 * P-7D.3
 *
 * Security objective:
 *
 * An authorization must bind not only to:
 *
 *   agent
 *   capability
 *   target
 *   selector
 *   amount
 *
 * but also to the semantic context in which the action was approved.
 *
 * This harness models two semantic commitments:
 *
 *   contextHash
 *   purposeHash
 *
 * If either changes, the authorization identity must change.
 */
contract SemanticIntentHarness is EIP712 {
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

    mapping(address => mapping(uint256 => bool)) public used;

    error InvalidSigner();
    error Replay();
    error Expired();

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


contract Attack_SemanticIntentBindingTest is Test {

    SemanticIntentHarness internal auth;

    uint256 internal constant AGENT_KEY =
        0xA11CE;

    address internal agent;

    bytes32 internal constant PAYMENT_CAPABILITY =
        keccak256("akmena.capability.payment");

    address internal constant PAYMENT_ROUTER =
        address(0x1000);

    bytes4 internal constant PAY_SELECTOR =
        bytes4(
            keccak256("pay(address,uint256)")
        );

    bytes32 internal constant ORIGINAL_CONTEXT =
        keccak256(
            "invoice:88492|recipient:alice|account:12345"
        );

    bytes32 internal constant ORIGINAL_PURPOSE =
        keccak256(
            "purpose:aws-infrastructure"
        );

    function setUp()
        public
    {
        auth =
            new SemanticIntentHarness();

        agent =
            vm.addr(AGENT_KEY);
    }

    function _intent(
        uint256 nonce
    )
        internal
        view
        returns (
            SemanticIntentHarness.SemanticIntent memory
        )
    {
        return
            SemanticIntentHarness.SemanticIntent({
                agent: agent,
                capability: PAYMENT_CAPABILITY,
                target: PAYMENT_ROUTER,
                selector: PAY_SELECTOR,
                amount: 500 ether,
                contextHash: ORIGINAL_CONTEXT,
                purposeHash: ORIGINAL_PURPOSE,
                nonce: nonce,
                deadline: block.timestamp + 1 hours
            });
    }

    function _sign(
        SemanticIntentHarness.SemanticIntent memory intent
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

    function test_OriginalSemanticIntentExecutes()
        public
    {
        SemanticIntentHarness.SemanticIntent memory intent =
            _intent(1);

        address signer =
            auth.execute(
                intent,
                _sign(intent)
            );

        assertEq(
            signer,
            agent
        );

        assertTrue(
            auth.used(agent, 1),
            "authorization must be consumed"
        );
    }

    function test_PurposeMutationChangesIdentity()
        public
        view
    {
        SemanticIntentHarness.SemanticIntent memory original =
            _intent(1);

        SemanticIntentHarness.SemanticIntent memory mutated =
            SemanticIntentHarness.SemanticIntent({
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
            mutated.purposeHash != original.purposeHash,
            "purpose mutation did not change field"
        );

        assertTrue(
            auth.hashIntent(original) !=
            auth.hashIntent(mutated),
            "CRITICAL: purpose mutation preserved authorization identity"
        );
    }

    function test_ContextMutationChangesIdentity()
        public
        view
    {
        SemanticIntentHarness.SemanticIntent memory original =
            _intent(1);

        SemanticIntentHarness.SemanticIntent memory mutated =
            SemanticIntentHarness.SemanticIntent({
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
            mutated.contextHash != original.contextHash,
            "context mutation did not change field"
        );

        assertTrue(
            auth.hashIntent(original) !=
            auth.hashIntent(mutated),
            "CRITICAL: context mutation preserved authorization identity"
        );
    }

    function test_RecipientSwapChangesContextIdentity()
        public
        view
    {
        SemanticIntentHarness.SemanticIntent memory original =
            _intent(1);

        SemanticIntentHarness.SemanticIntent memory mutated =
            SemanticIntentHarness.SemanticIntent({
                agent: original.agent,
                capability: original.capability,
                target: original.target,
                selector: original.selector,
                amount: original.amount,
                contextHash: bytes32(uint256(0x3333)),
                purposeHash: original.purposeHash,
                nonce: original.nonce,
                deadline: original.deadline
            });

        assertTrue(
            mutated.contextHash != original.contextHash,
            "recipient mutation did not change field"
        );

        assertTrue(
            auth.hashIntent(original) !=
            auth.hashIntent(mutated)
        );
    }

    function test_InvoiceSwapChangesContextIdentity()
        public
        view
    {
        SemanticIntentHarness.SemanticIntent memory original =
            _intent(1);

        SemanticIntentHarness.SemanticIntent memory mutated =
            SemanticIntentHarness.SemanticIntent({
                agent: original.agent,
                capability: original.capability,
                target: original.target,
                selector: original.selector,
                amount: original.amount,
                contextHash: bytes32(uint256(0x4444)),
                purposeHash: original.purposeHash,
                nonce: original.nonce,
                deadline: original.deadline
            });

        assertTrue(
            mutated.contextHash != original.contextHash,
            "invoice mutation did not change field"
        );

        assertTrue(
            auth.hashIntent(original) !=
            auth.hashIntent(mutated)
        );
    }

    function test_ContextMutationInvalidatesOriginalSignature()
        public
    {
        SemanticIntentHarness.SemanticIntent memory original =
            _intent(1);

        bytes memory signature =
            _sign(original);

        SemanticIntentHarness.SemanticIntent memory mutated =
            SemanticIntentHarness.SemanticIntent({
                agent: original.agent,
                capability: original.capability,
                target: original.target,
                selector: original.selector,
                amount: original.amount,
                contextHash: bytes32(uint256(0x3333)),
                purposeHash: original.purposeHash,
                nonce: original.nonce,
                deadline: original.deadline
            });

        vm.expectRevert(
            SemanticIntentHarness.InvalidSigner.selector
        );

        auth.execute(
            mutated,
            signature
        );
    }

    function test_PurposeMutationInvalidatesOriginalSignature()
        public
    {
        SemanticIntentHarness.SemanticIntent memory original =
            _intent(1);

        bytes memory signature =
            _sign(original);

        SemanticIntentHarness.SemanticIntent memory mutated =
            original;

        mutated.purposeHash =
            bytes32(uint256(0x5555));

        vm.expectRevert(
            SemanticIntentHarness.InvalidSigner.selector
        );

        auth.execute(
            mutated,
            signature
        );
    }

    function test_InvoiceAndRecipientCannotBothChange()
        public
    {
        SemanticIntentHarness.SemanticIntent memory original =
            _intent(1);

        bytes memory signature =
            _sign(original);

        SemanticIntentHarness.SemanticIntent memory mutated =
            SemanticIntentHarness.SemanticIntent({
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

        vm.expectRevert(
            SemanticIntentHarness.InvalidSigner.selector
        );

        auth.execute(
            mutated,
            signature
        );
    }

    function test_SemanticMutationCannotBypassReplayProtection()
        public
    {
        SemanticIntentHarness.SemanticIntent memory original =
            _intent(1);

        bytes memory signature =
            _sign(original);

        auth.execute(
            original,
            signature
        );

        assertTrue(
            auth.used(agent, 1)
        );

        SemanticIntentHarness.SemanticIntent memory mutated =
            original;

        mutated.purposeHash =
            bytes32(uint256(0x6666));

        vm.expectRevert(
            SemanticIntentHarness.InvalidSigner.selector
        );

        auth.execute(
            mutated,
            signature
        );
    }
}
