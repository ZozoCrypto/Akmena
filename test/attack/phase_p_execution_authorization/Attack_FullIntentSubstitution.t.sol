// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract FullIntentSubstitutionHarness is EIP712 {
    using ECDSA for bytes32;

    bytes32 public constant TYPEHASH =
        keccak256(
            "ExecutionIntent(address agent,bytes32 capability,address target,bytes4 selector,uint256 amount,bytes32 contextHash,bytes32 purposeHash,uint256 nonce,uint256 deadline)"
        );

    struct Intent {
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
        EIP712("AkmenaFullIntentSubstitution", "1")
    {}

    function hashIntent(
        Intent memory intent
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
        Intent calldata intent,
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

contract Attack_FullIntentSubstitutionTest is Test {

    FullIntentSubstitutionHarness internal auth;

    uint256 internal constant AGENT_KEY =
        0xA11CE;

    uint256 internal constant OTHER_AGENT_KEY =
        0xB0B;

    address internal agent;
    address internal otherAgent;

    bytes32 internal constant CAPABILITY =
        keccak256("akmena.capability.payment");

    bytes32 internal constant OTHER_CAPABILITY =
        keccak256("akmena.capability.admin");

    address internal constant TARGET =
        address(0x1000);

    address internal constant OTHER_TARGET =
        address(0x2000);

    bytes4 internal constant SELECTOR =
        bytes4(
            keccak256("pay(address,uint256)")
        );

    bytes4 internal constant OTHER_SELECTOR =
        bytes4(
            keccak256("withdraw(address,uint256)")
        );

    bytes32 internal constant CONTEXT =
        keccak256(
            "invoice:88492|recipient:alice|account:12345"
        );

    bytes32 internal constant OTHER_CONTEXT =
        keccak256(
            "invoice:99999|recipient:bob|account:99999"
        );

    bytes32 internal constant PURPOSE =
        keccak256(
            "purpose:aws-infrastructure"
        );

    bytes32 internal constant OTHER_PURPOSE =
        keccak256(
            "purpose:treasury-withdrawal"
        );

    function setUp()
        public
    {
        auth =
            new FullIntentSubstitutionHarness();

        agent =
            vm.addr(AGENT_KEY);

        otherAgent =
            vm.addr(OTHER_AGENT_KEY);
    }

    function _intent(
        uint256 nonce
    )
        internal
        view
        returns (
            FullIntentSubstitutionHarness.Intent memory
        )
    {
        return
            FullIntentSubstitutionHarness.Intent({
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
        FullIntentSubstitutionHarness.Intent memory intent
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

    function test_OriginalIntentExecutes()
        public
    {
        FullIntentSubstitutionHarness.Intent memory intent =
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
            auth.used(agent, 1)
        );
    }

    function test_AgentSubstitutionFails()
        public
    {
        FullIntentSubstitutionHarness.Intent memory original =
            _intent(1);

        bytes memory signature =
            _sign(original);

        FullIntentSubstitutionHarness.Intent memory mutated =
            FullIntentSubstitutionHarness.Intent({
                agent: otherAgent,
                capability: original.capability,
                target: original.target,
                selector: original.selector,
                amount: original.amount,
                contextHash: original.contextHash,
                purposeHash: original.purposeHash,
                nonce: original.nonce,
                deadline: original.deadline
            });

        vm.expectRevert(
            FullIntentSubstitutionHarness.InvalidSigner.selector
        );

        auth.execute(
            mutated,
            signature
        );
    }

    function test_CapabilitySubstitutionFails()
        public
    {
        FullIntentSubstitutionHarness.Intent memory original =
            _intent(1);

        bytes memory signature =
            _sign(original);

        FullIntentSubstitutionHarness.Intent memory mutated =
            FullIntentSubstitutionHarness.Intent({
                agent: original.agent,
                capability: OTHER_CAPABILITY,
                target: original.target,
                selector: original.selector,
                amount: original.amount,
                contextHash: original.contextHash,
                purposeHash: original.purposeHash,
                nonce: original.nonce,
                deadline: original.deadline
            });

        vm.expectRevert(
            FullIntentSubstitutionHarness.InvalidSigner.selector
        );

        auth.execute(
            mutated,
            signature
        );
    }

    function test_TargetSubstitutionFails()
        public
    {
        FullIntentSubstitutionHarness.Intent memory original =
            _intent(1);

        bytes memory signature =
            _sign(original);

        FullIntentSubstitutionHarness.Intent memory mutated =
            FullIntentSubstitutionHarness.Intent({
                agent: original.agent,
                capability: original.capability,
                target: OTHER_TARGET,
                selector: original.selector,
                amount: original.amount,
                contextHash: original.contextHash,
                purposeHash: original.purposeHash,
                nonce: original.nonce,
                deadline: original.deadline
            });

        vm.expectRevert(
            FullIntentSubstitutionHarness.InvalidSigner.selector
        );

        auth.execute(
            mutated,
            signature
        );
    }

    function test_SelectorSubstitutionFails()
        public
    {
        FullIntentSubstitutionHarness.Intent memory original =
            _intent(1);

        bytes memory signature =
            _sign(original);

        FullIntentSubstitutionHarness.Intent memory mutated =
            FullIntentSubstitutionHarness.Intent({
                agent: original.agent,
                capability: original.capability,
                target: original.target,
                selector: OTHER_SELECTOR,
                amount: original.amount,
                contextHash: original.contextHash,
                purposeHash: original.purposeHash,
                nonce: original.nonce,
                deadline: original.deadline
            });

        vm.expectRevert(
            FullIntentSubstitutionHarness.InvalidSigner.selector
        );

        auth.execute(
            mutated,
            signature
        );
    }

    function test_AmountSubstitutionFails()
        public
    {
        FullIntentSubstitutionHarness.Intent memory original =
            _intent(1);

        bytes memory signature =
            _sign(original);

        FullIntentSubstitutionHarness.Intent memory mutated =
            FullIntentSubstitutionHarness.Intent({
                agent: original.agent,
                capability: original.capability,
                target: original.target,
                selector: original.selector,
                amount: original.amount + 1,
                contextHash: original.contextHash,
                purposeHash: original.purposeHash,
                nonce: original.nonce,
                deadline: original.deadline
            });

        vm.expectRevert(
            FullIntentSubstitutionHarness.InvalidSigner.selector
        );

        auth.execute(
            mutated,
            signature
        );
    }

    function test_ContextSubstitutionFails()
        public
    {
        FullIntentSubstitutionHarness.Intent memory original =
            _intent(1);

        bytes memory signature =
            _sign(original);

        FullIntentSubstitutionHarness.Intent memory mutated =
            FullIntentSubstitutionHarness.Intent({
                agent: original.agent,
                capability: original.capability,
                target: original.target,
                selector: original.selector,
                amount: original.amount,
                contextHash: OTHER_CONTEXT,
                purposeHash: original.purposeHash,
                nonce: original.nonce,
                deadline: original.deadline
            });

        vm.expectRevert(
            FullIntentSubstitutionHarness.InvalidSigner.selector
        );

        auth.execute(
            mutated,
            signature
        );
    }

    function test_PurposeSubstitutionFails()
        public
    {
        FullIntentSubstitutionHarness.Intent memory original =
            _intent(1);

        bytes memory signature =
            _sign(original);

        FullIntentSubstitutionHarness.Intent memory mutated =
            FullIntentSubstitutionHarness.Intent({
                agent: original.agent,
                capability: original.capability,
                target: original.target,
                selector: original.selector,
                amount: original.amount,
                contextHash: original.contextHash,
                purposeHash: OTHER_PURPOSE,
                nonce: original.nonce,
                deadline: original.deadline
            });

        vm.expectRevert(
            FullIntentSubstitutionHarness.InvalidSigner.selector
        );

        auth.execute(
            mutated,
            signature
        );
    }

    function test_NonceSubstitutionFails()
        public
    {
        FullIntentSubstitutionHarness.Intent memory original =
            _intent(1);

        bytes memory signature =
            _sign(original);

        FullIntentSubstitutionHarness.Intent memory mutated =
            FullIntentSubstitutionHarness.Intent({
                agent: original.agent,
                capability: original.capability,
                target: original.target,
                selector: original.selector,
                amount: original.amount,
                contextHash: original.contextHash,
                purposeHash: original.purposeHash,
                nonce: 2,
                deadline: original.deadline
            });

        vm.expectRevert(
            FullIntentSubstitutionHarness.InvalidSigner.selector
        );

        auth.execute(
            mutated,
            signature
        );
    }

    function test_DeadlineSubstitutionFails()
        public
    {
        FullIntentSubstitutionHarness.Intent memory original =
            _intent(1);

        bytes memory signature =
            _sign(original);

        FullIntentSubstitutionHarness.Intent memory mutated =
            FullIntentSubstitutionHarness.Intent({
                agent: original.agent,
                capability: original.capability,
                target: original.target,
                selector: original.selector,
                amount: original.amount,
                contextHash: original.contextHash,
                purposeHash: original.purposeHash,
                nonce: original.nonce,
                deadline: original.deadline + 1
            });

        vm.expectRevert(
            FullIntentSubstitutionHarness.InvalidSigner.selector
        );

        auth.execute(
            mutated,
            signature
        );
    }

    function test_MultipleFieldSubstitutionFails()
        public
    {
        FullIntentSubstitutionHarness.Intent memory original =
            _intent(1);

        bytes memory signature =
            _sign(original);

        FullIntentSubstitutionHarness.Intent memory mutated =
            FullIntentSubstitutionHarness.Intent({
                agent: original.agent,
                capability: OTHER_CAPABILITY,
                target: OTHER_TARGET,
                selector: OTHER_SELECTOR,
                amount: original.amount + 1,
                contextHash: OTHER_CONTEXT,
                purposeHash: OTHER_PURPOSE,
                nonce: 2,
                deadline: original.deadline + 1
            });

        vm.expectRevert(
            FullIntentSubstitutionHarness.InvalidSigner.selector
        );

        auth.execute(
            mutated,
            signature
        );
    }
}
