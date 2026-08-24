// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract AgentNonceHarness is EIP712 {
    using ECDSA for bytes32;

    bytes32 public constant TYPEHASH =
        keccak256(
            "AgentIntent(address agent,bytes32 lane,uint256 nonce,address target,uint256 amount,uint256 deadline)"
        );

    struct AgentIntent {
        address agent;
        bytes32 lane;
        uint256 nonce;
        address target;
        uint256 amount;
        uint256 deadline;
    }

    mapping(address => mapping(bytes32 => mapping(uint256 => bool)))
        public used;

    error InvalidSigner();
    error Replay();
    error Expired();

    constructor()
        EIP712("AkmenaAgentAuthorization", "1")
    {}

    function hashIntent(
        AgentIntent memory intent
    ) public view returns (bytes32) {
        bytes32 structHash = keccak256(
            abi.encode(
                TYPEHASH,
                intent.agent,
                intent.lane,
                intent.nonce,
                intent.target,
                intent.amount,
                intent.deadline
            )
        );

        return _hashTypedDataV4(structHash);
    }

    function execute(
        AgentIntent calldata intent,
        bytes calldata signature
    ) external returns (address signer) {
        if (block.timestamp > intent.deadline) {
            revert Expired();
        }

        if (used[intent.agent][intent.lane][intent.nonce]) {
            revert Replay();
        }

        signer = hashIntent(intent).recover(signature);

        if (signer != intent.agent) {
            revert InvalidSigner();
        }

        used[intent.agent][intent.lane][intent.nonce] = true;
    }
}

contract Attack_AgentNonceArchitectureTest is Test {
    AgentNonceHarness internal auth;

    uint256 internal constant AGENT_KEY =
        0xA11CE;

    uint256 internal constant ATTACKER_KEY =
        0xB0B;

    address internal agent;
    address internal attacker;

    address internal constant TARGET_A =
        address(0xAAAA);

    address internal constant TARGET_B =
        address(0xBBBB);

    bytes32 internal constant PAYMENT_LANE =
        keccak256("akmena.lane.payment");

    bytes32 internal constant ESCROW_LANE =
        keccak256("akmena.lane.escrow");

    function setUp() public {
        auth = new AgentNonceHarness();

        agent = vm.addr(AGENT_KEY);
        attacker = vm.addr(ATTACKER_KEY);
    }

    function _intent(
        bytes32 lane,
        uint256 nonce,
        address target
    )
        internal
        view
        returns (AgentNonceHarness.AgentIntent memory)
    {
        return AgentNonceHarness.AgentIntent({
            agent: agent,
            lane: lane,
            nonce: nonce,
            target: target,
            amount: 1 ether,
            deadline: block.timestamp + 1 hours
        });
    }

    function _sign(
        AgentNonceHarness.AgentIntent memory intent
    )
        internal
        view
        returns (bytes memory)
    {
        bytes32 digest = auth.hashIntent(intent);

        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(AGENT_KEY, digest);

        return abi.encodePacked(r, s, v);
    }

    function test_SameAgentSameLaneSameNonceReplays()
        public
    {
        AgentNonceHarness.AgentIntent memory intent =
            _intent(PAYMENT_LANE, 1, TARGET_A);

        bytes memory signature = _sign(intent);

        auth.execute(intent, signature);

        vm.expectRevert(
            AgentNonceHarness.Replay.selector
        );

        auth.execute(intent, signature);
    }

    function test_DifferentLanesCanUseSameNonce()
        public
    {
        AgentNonceHarness.AgentIntent memory payment =
            _intent(
                PAYMENT_LANE,
                1,
                TARGET_A
            );

        AgentNonceHarness.AgentIntent memory escrow =
            _intent(
                ESCROW_LANE,
                1,
                TARGET_B
            );

        bytes memory paymentSig = _sign(payment);
        bytes memory escrowSig = _sign(escrow);

        auth.execute(payment, paymentSig);
        auth.execute(escrow, escrowSig);

        assertTrue(
            auth.used(agent, PAYMENT_LANE, 1)
        );

        assertTrue(
            auth.used(agent, ESCROW_LANE, 1)
        );
    }

    function test_SameNonceDifferentTargetStillRequiresNewSignature()
        public
    {
        AgentNonceHarness.AgentIntent memory original =
            _intent(
                PAYMENT_LANE,
                1,
                TARGET_A
            );

        bytes memory signature = _sign(original);

        AgentNonceHarness.AgentIntent memory mutated =
            original;

        mutated.target = TARGET_B;

        vm.expectRevert(
            AgentNonceHarness.InvalidSigner.selector
        );

        auth.execute(
            mutated,
            signature
        );
    }

    function test_SameNonceDifferentAmountRequiresNewSignature()
        public
    {
        AgentNonceHarness.AgentIntent memory original =
            _intent(
                PAYMENT_LANE,
                1,
                TARGET_A
            );

        bytes memory signature = _sign(original);

        AgentNonceHarness.AgentIntent memory mutated =
            original;

        mutated.amount = 100 ether;

        vm.expectRevert(
            AgentNonceHarness.InvalidSigner.selector
        );

        auth.execute(
            mutated,
            signature
        );
    }

    function test_AttackerCannotConsumeAgentsNonce()
        public
    {
        AgentNonceHarness.AgentIntent memory intent =
            _intent(
                PAYMENT_LANE,
                1,
                TARGET_A
            );

        bytes memory attackerSignature;

        bytes32 digest = auth.hashIntent(intent);

        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(
                ATTACKER_KEY,
                digest
            );

        attackerSignature =
            abi.encodePacked(r, s, v);

        vm.expectRevert(
            AgentNonceHarness.InvalidSigner.selector
        );

        auth.execute(
            intent,
            attackerSignature
        );

        assertFalse(
            auth.used(agent, PAYMENT_LANE, 1),
            "CRITICAL: attacker consumed agent nonce"
        );
    }

    function test_ParallelLanesDoNotBlockEachOther()
        public
    {
        AgentNonceHarness.AgentIntent memory payment1 =
            _intent(
                PAYMENT_LANE,
                1,
                TARGET_A
            );

        AgentNonceHarness.AgentIntent memory escrow1 =
            _intent(
                ESCROW_LANE,
                1,
                TARGET_B
            );

        AgentNonceHarness.AgentIntent memory payment2 =
            _intent(
                PAYMENT_LANE,
                2,
                TARGET_A
            );

        auth.execute(
            payment1,
            _sign(payment1)
        );

        auth.execute(
            escrow1,
            _sign(escrow1)
        );

        auth.execute(
            payment2,
            _sign(payment2)
        );

        assertTrue(
            auth.used(agent, PAYMENT_LANE, 1)
        );

        assertTrue(
            auth.used(agent, PAYMENT_LANE, 2)
        );

        assertTrue(
            auth.used(agent, ESCROW_LANE, 1)
        );
    }

    function test_LaneMutationInvalidatesSignature()
        public
    {
        AgentNonceHarness.AgentIntent memory original =
            _intent(
                PAYMENT_LANE,
                1,
                TARGET_A
            );

        bytes memory signature = _sign(original);

        AgentNonceHarness.AgentIntent memory mutated =
            original;

        mutated.lane = ESCROW_LANE;

        vm.expectRevert(
            AgentNonceHarness.InvalidSigner.selector
        );

        auth.execute(
            mutated,
            signature
        );
    }

    function test_AgentMutationInvalidatesSignature()
        public
    {
        AgentNonceHarness.AgentIntent memory original =
            _intent(
                PAYMENT_LANE,
                1,
                TARGET_A
            );

        bytes memory signature = _sign(original);

        AgentNonceHarness.AgentIntent memory mutated =
            original;

        mutated.agent = attacker;

        vm.expectRevert(
            AgentNonceHarness.InvalidSigner.selector
        );

        auth.execute(
            mutated,
            signature
        );
    }

    function test_ZeroNonceIsStillAValidExplicitNonce()
        public
    {
        AgentNonceHarness.AgentIntent memory intent =
            _intent(
                PAYMENT_LANE,
                0,
                TARGET_A
            );

        auth.execute(
            intent,
            _sign(intent)
        );

        assertTrue(
            auth.used(agent, PAYMENT_LANE, 0)
        );
    }
}
