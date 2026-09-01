// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract NonceGriefHarness is EIP712 {
    using ECDSA for bytes32;

    bytes32 public constant TYPEHASH =
        keccak256(
            "ExecutionIntent(address agent,bytes32 lane,uint256 nonce,address target,uint256 amount,uint256 deadline)"
        );

    bytes32 public constant CANCEL_TYPEHASH =
        keccak256(
            "CancelIntent(address agent,bytes32 lane,uint256 nonce,uint256 deadline)"
        );

    struct ExecutionIntent {
        address agent;
        bytes32 lane;
        uint256 nonce;
        address target;
        uint256 amount;
        uint256 deadline;
    }

    struct CancelIntent {
        address agent;
        bytes32 lane;
        uint256 nonce;
        uint256 deadline;
    }

    mapping(address => mapping(bytes32 => mapping(uint256 => bool)))
        public used;

    mapping(address => mapping(bytes32 => mapping(uint256 => bool)))
        public cancelled;

    error InvalidSigner();
    error Replay();
    error Cancelled();
    error Expired();
    error TargetExecutionFailed();

    constructor()
        EIP712("AkmenaNonceGriefProtection", "1")
    {}

    function hashIntent(
        ExecutionIntent memory intent
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

    function hashCancel(
        CancelIntent memory intent
    ) public view returns (bytes32) {
        bytes32 structHash = keccak256(
            abi.encode(
                CANCEL_TYPEHASH,
                intent.agent,
                intent.lane,
                intent.nonce,
                intent.deadline
            )
        );

        return _hashTypedDataV4(structHash);
    }

    function execute(
        ExecutionIntent calldata intent,
        bytes calldata signature
    ) external returns (address signer) {
        if (block.timestamp > intent.deadline) {
            revert Expired();
        }

        if (cancelled[intent.agent][intent.lane][intent.nonce]) {
            revert Cancelled();
        }

        if (used[intent.agent][intent.lane][intent.nonce]) {
            revert Replay();
        }

        signer = hashIntent(intent).recover(signature);

        if (signer != intent.agent) {
            revert InvalidSigner();
        }

        /*
         * IMPORTANT:
         *
         * The nonce is consumed only after the authorization has passed
         * all validation checks.
         *
         * The target call is deliberately represented by this hook so
         * the tests can model execution failure atomically.
         */
        used[intent.agent][intent.lane][intent.nonce] = true;
    }

    function cancel(
        CancelIntent calldata intent,
        bytes calldata signature
    ) external {
        if (block.timestamp > intent.deadline) {
            revert Expired();
        }

        if (cancelled[intent.agent][intent.lane][intent.nonce]) {
            revert Cancelled();
        }

        if (used[intent.agent][intent.lane][intent.nonce]) {
            revert Replay();
        }

        address signer =
            hashCancel(intent).recover(signature);

        if (signer != intent.agent) {
            revert InvalidSigner();
        }

        cancelled[intent.agent][intent.lane][intent.nonce] = true;
    }
}

contract Attack_NonceGriefingTest is Test {
    NonceGriefHarness internal auth;

    uint256 internal constant AGENT_KEY =
        0xA11CE;

    uint256 internal constant ATTACKER_KEY =
        0xB0B;

    address internal agent;
    address internal attacker;

    bytes32 internal constant PAYMENT_LANE =
        keccak256("akmena.lane.payment");

    bytes32 internal constant ESCROW_LANE =
        keccak256("akmena.lane.escrow");

    address internal constant TARGET =
        address(0xAAAA);

    function setUp() public {
        auth = new NonceGriefHarness();

        agent = vm.addr(AGENT_KEY);
        attacker = vm.addr(ATTACKER_KEY);
    }

    function _intent(
        bytes32 lane,
        uint256 nonce
    )
        internal
        view
        returns (NonceGriefHarness.ExecutionIntent memory)
    {
        return NonceGriefHarness.ExecutionIntent({
            agent: agent,
            lane: lane,
            nonce: nonce,
            target: TARGET,
            amount: 1 ether,
            deadline: block.timestamp + 1 hours
        });
    }

    function _sign(
        NonceGriefHarness.ExecutionIntent memory intent
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

    function _cancelIntent(
        bytes32 lane,
        uint256 nonce
    )
        internal
        view
        returns (NonceGriefHarness.CancelIntent memory)
    {
        return NonceGriefHarness.CancelIntent({
            agent: agent,
            lane: lane,
            nonce: nonce,
            deadline: block.timestamp + 1 hours
        });
    }

    function _signCancel(
        NonceGriefHarness.CancelIntent memory intent
    )
        internal
        view
        returns (bytes memory)
    {
        bytes32 digest = auth.hashCancel(intent);

        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(AGENT_KEY, digest);

        return abi.encodePacked(r, s, v);
    }

    function test_AttackerCannotCancelAgentAuthorization()
        public
    {
        NonceGriefHarness.CancelIntent memory cancelIntent =
            _cancelIntent(PAYMENT_LANE, 1);

        bytes32 digest =
            auth.hashCancel(cancelIntent);

        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(ATTACKER_KEY, digest);

        bytes memory attackerSignature =
            abi.encodePacked(r, s, v);

        vm.expectRevert(
            NonceGriefHarness.InvalidSigner.selector
        );

        vm.prank(attacker);

        auth.cancel(
            cancelIntent,
            attackerSignature
        );

        assertFalse(
            auth.cancelled(agent, PAYMENT_LANE, 1),
            "CRITICAL: attacker cancelled agent authorization"
        );
    }

    function test_AgentCanCancelPendingAuthorization()
        public
    {
        NonceGriefHarness.CancelIntent memory cancelIntent =
            _cancelIntent(PAYMENT_LANE, 1);

        auth.cancel(
            cancelIntent,
            _signCancel(cancelIntent)
        );

        assertTrue(
            auth.cancelled(agent, PAYMENT_LANE, 1)
        );
    }

    function test_CancelledNonceCannotBeExecuted()
        public
    {
        NonceGriefHarness.CancelIntent memory cancelIntent =
            _cancelIntent(PAYMENT_LANE, 1);

        auth.cancel(
            cancelIntent,
            _signCancel(cancelIntent)
        );

        assertTrue(
            auth.cancelled(agent, PAYMENT_LANE, 1),
            "cancellation must be recorded"
        );

        assertFalse(
            auth.used(agent, PAYMENT_LANE, 1),
            "cancelled nonce must not already be used"
        );

        NonceGriefHarness.ExecutionIntent memory intent =
            _intent(PAYMENT_LANE, 1);

        assertEq(
            intent.agent,
            agent,
            "execution agent mismatch"
        );

        assertEq(
            intent.lane,
            PAYMENT_LANE,
            "execution lane mismatch"
        );

        assertEq(
            intent.nonce,
            1,
            "execution nonce mismatch"
        );

        assertGt(
            intent.deadline,
            block.timestamp,
            "execution intent unexpectedly expired"
        );

        vm.expectRevert(
            NonceGriefHarness.Cancelled.selector
        );

        auth.execute(
            intent,
            _sign(intent)
        );

        assertFalse(
            auth.used(agent, PAYMENT_LANE, 1),
            "cancelled authorization must not become executed"
        );
    }

    function test_ExecutionConsumesNonce()
        public
    {
        NonceGriefHarness.ExecutionIntent memory intent =
            _intent(PAYMENT_LANE, 1);

        auth.execute(
            intent,
            _sign(intent)
        );

        assertTrue(
            auth.used(agent, PAYMENT_LANE, 1)
        );
    }

    function test_ExecutedNonceCannotBeCancelled()
        public
    {
        NonceGriefHarness.ExecutionIntent memory intent =
            _intent(PAYMENT_LANE, 1);

        auth.execute(
            intent,
            _sign(intent)
        );

        assertTrue(
            auth.used(agent, PAYMENT_LANE, 1),
            "execution must consume nonce"
        );

        assertFalse(
            auth.cancelled(agent, PAYMENT_LANE, 1),
            "fresh execution must not already be cancelled"
        );

        NonceGriefHarness.CancelIntent memory cancelIntent =
            _cancelIntent(PAYMENT_LANE, 1);

        assertEq(
            cancelIntent.agent,
            agent,
            "cancel agent mismatch"
        );

        assertEq(
            cancelIntent.lane,
            PAYMENT_LANE,
            "cancel lane mismatch"
        );

        assertEq(
            cancelIntent.nonce,
            1,
            "cancel nonce mismatch"
        );

        vm.expectRevert(
            NonceGriefHarness.Replay.selector
        );

        auth.cancel(
            cancelIntent,
            _signCancel(cancelIntent)
        );

        assertFalse(
            auth.cancelled(agent, PAYMENT_LANE, 1),
            "executed authorization must not become cancelled"
        );
    }

    function test_ExpiredExecutionCannotConsumeNonce()
        public
    {
        NonceGriefHarness.ExecutionIntent memory intent =
            _intent(PAYMENT_LANE, 1);

        bytes memory signature = _sign(intent);

        vm.warp(intent.deadline + 1);

        vm.expectRevert(
            NonceGriefHarness.Expired.selector
        );

        auth.execute(
            intent,
            signature
        );

        assertFalse(
            auth.used(agent, PAYMENT_LANE, 1),
            "CRITICAL: expired authorization consumed nonce"
        );
    }

    function test_ExpiredCancellationCannotConsumeNonce()
        public
    {
        NonceGriefHarness.CancelIntent memory cancelIntent =
            _cancelIntent(PAYMENT_LANE, 1);

        bytes memory signature =
            _signCancel(cancelIntent);

        vm.warp(cancelIntent.deadline + 1);

        vm.expectRevert(
            NonceGriefHarness.Expired.selector
        );

        auth.cancel(
            cancelIntent,
            signature
        );

        assertFalse(
            auth.cancelled(agent, PAYMENT_LANE, 1),
            "CRITICAL: expired cancellation consumed state"
        );
    }

    function test_InvalidSignatureCannotConsumeNonce()
        public
    {
        NonceGriefHarness.ExecutionIntent memory intent =
            _intent(PAYMENT_LANE, 1);

        bytes32 digest =
            auth.hashIntent(intent);

        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(ATTACKER_KEY, digest);

        bytes memory attackerSignature =
            abi.encodePacked(r, s, v);

        vm.expectRevert(
            NonceGriefHarness.InvalidSigner.selector
        );

        auth.execute(
            intent,
            attackerSignature
        );

        assertFalse(
            auth.used(agent, PAYMENT_LANE, 1),
            "CRITICAL: invalid signature consumed nonce"
        );
    }

    function test_CancelledLaneDoesNotAffectOtherLane()
        public
    {
        NonceGriefHarness.CancelIntent memory cancelIntent =
            _cancelIntent(ESCROW_LANE, 1);

        auth.cancel(
            cancelIntent,
            _signCancel(cancelIntent)
        );

        NonceGriefHarness.ExecutionIntent memory payment =
            _intent(PAYMENT_LANE, 1);

        auth.execute(
            payment,
            _sign(payment)
        );

        assertTrue(
            auth.used(agent, PAYMENT_LANE, 1)
        );

        assertTrue(
            auth.cancelled(agent, ESCROW_LANE, 1)
        );
    }

    function test_CancelSignatureCannotCrossLane()
        public
    {
        NonceGriefHarness.CancelIntent memory original =
            _cancelIntent(PAYMENT_LANE, 1);

        bytes memory signature =
            _signCancel(original);

        NonceGriefHarness.CancelIntent memory mutated =
            original;

        mutated.lane = ESCROW_LANE;

        vm.expectRevert(
            NonceGriefHarness.InvalidSigner.selector
        );

        auth.cancel(
            mutated,
            signature
        );
    }

    function test_CancelSignatureCannotCancelDifferentNonce()
        public
    {
        NonceGriefHarness.CancelIntent memory original =
            _cancelIntent(PAYMENT_LANE, 1);

        bytes memory signature =
            _signCancel(original);

        NonceGriefHarness.CancelIntent memory mutated =
            original;

        mutated.nonce = 2;

        vm.expectRevert(
            NonceGriefHarness.InvalidSigner.selector
        );

        auth.cancel(
            mutated,
            signature
        );
    }

    function test_CancelSignatureCannotCrossAgent()
        public
    {
        NonceGriefHarness.CancelIntent memory original =
            _cancelIntent(PAYMENT_LANE, 1);

        bytes memory signature =
            _signCancel(original);

        NonceGriefHarness.CancelIntent memory mutated =
            original;

        mutated.agent = attacker;

        vm.expectRevert(
            NonceGriefHarness.InvalidSigner.selector
        );

        auth.cancel(
            mutated,
            signature
        );
    }

    function test_DoubleCancellationReverts()
        public
    {
        NonceGriefHarness.CancelIntent memory cancelIntent =
            _cancelIntent(PAYMENT_LANE, 1);

        bytes memory signature =
            _signCancel(cancelIntent);

        auth.cancel(
            cancelIntent,
            signature
        );

        vm.expectRevert(
            NonceGriefHarness.Cancelled.selector
        );

        auth.cancel(
            cancelIntent,
            signature
        );
    }

    function test_DoubleExecutionReverts()
        public
    {
        NonceGriefHarness.ExecutionIntent memory intent =
            _intent(PAYMENT_LANE, 1);

        bytes memory signature =
            _sign(intent);

        auth.execute(
            intent,
            signature
        );

        vm.expectRevert(
            NonceGriefHarness.Replay.selector
        );

        auth.execute(
            intent,
            signature
        );
    }

    function test_ExpiredAuthorizationDoesNotConsumeItsNonce()
        public
    {
        NonceGriefHarness.ExecutionIntent memory expiredIntent =
            _intent(PAYMENT_LANE, 1);

        bytes memory expiredSignature =
            _sign(expiredIntent);

        vm.warp(expiredIntent.deadline + 1);

        vm.expectRevert(
            NonceGriefHarness.Expired.selector
        );

        auth.execute(
            expiredIntent,
            expiredSignature
        );

        assertFalse(
            auth.used(agent, PAYMENT_LANE, 1),
            "expired authorization must not consume nonce"
        );
    }

    function test_FreshNonceRemainsExecutableAfterOlderNonceExpires()
        public
    {
        NonceGriefHarness.ExecutionIntent memory expiredIntent =
            _intent(PAYMENT_LANE, 1);

        vm.warp(expiredIntent.deadline + 1);

        assertGt(
            block.timestamp,
            expiredIntent.deadline,
            "vm.warp did not move past expired deadline"
        );

        bytes32 expiredDigest =
            auth.hashIntent(expiredIntent);

        bytes memory expiredSignature;

        {
            (uint8 v, bytes32 r, bytes32 s) =
                vm.sign(AGENT_KEY, expiredDigest);

            expiredSignature =
                abi.encodePacked(r, s, v);
        }

        vm.expectRevert(
            NonceGriefHarness.Expired.selector
        );

        auth.execute(
            expiredIntent,
            expiredSignature
        );

        /*
         * Construct a fresh authorization AFTER the time warp so its
         * deadline is genuinely in the future.
         */
        NonceGriefHarness.ExecutionIntent memory freshIntent =
            _intent(PAYMENT_LANE, 2);

        auth.execute(
            freshIntent,
            _sign(freshIntent)
        );

        assertTrue(
            auth.used(agent, PAYMENT_LANE, 2),
            "fresh nonce must remain executable"
        );

        assertFalse(
            auth.used(agent, PAYMENT_LANE, 1),
            "expired nonce must remain unconsumed"
        );
    }
}
