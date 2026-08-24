// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract AuthorizationReplayHarness is EIP712 {
    using ECDSA for bytes32;

    bytes32 public constant TYPEHASH =
        keccak256(
            "Authorization(address agent,bytes32 lane,uint256 nonce,uint256 deadline)"
        );

    enum State {
        NONE,
        EXECUTED,
        CANCELLED,
        EXPIRED
    }

    struct Authorization {
        address agent;
        bytes32 lane;
        uint256 nonce;
        uint256 deadline;
    }

    mapping(address => mapping(bytes32 => mapping(uint256 => State)))
        public state;

    error InvalidSigner();
    error Replay();
    error Cancelled();
    error Expired();

    constructor()
        EIP712("AkmenaAuthorizationReplay", "1")
    {}

    function hashAuthorization(
        Authorization memory auth
    )
        public
        view
        returns (bytes32)
    {
        return _hashTypedDataV4(
            keccak256(
                abi.encode(
                    TYPEHASH,
                    auth.agent,
                    auth.lane,
                    auth.nonce,
                    auth.deadline
                )
            )
        );
    }

    function execute(
        Authorization calldata auth,
        bytes calldata signature
    )
        external
        returns (address signer)
    {
        State current =
            state[
                auth.agent
            ][
                auth.lane
            ][
                auth.nonce
            ];

        if (current == State.EXECUTED) {
            revert Replay();
        }

        if (current == State.CANCELLED) {
            revert Cancelled();
        }

        if (block.timestamp > auth.deadline) {
            state[
                auth.agent
            ][
                auth.lane
            ][
                auth.nonce
            ] = State.EXPIRED;

            revert Expired();
        }

        signer =
            hashAuthorization(auth).recover(signature);

        if (signer != auth.agent) {
            revert InvalidSigner();
        }

        state[
            auth.agent
        ][
            auth.lane
        ][
            auth.nonce
        ] = State.EXECUTED;
    }

    function cancel(
        Authorization calldata auth,
        bytes calldata signature
    )
        external
    {
        State current =
            state[
                auth.agent
            ][
                auth.lane
            ][
                auth.nonce
            ];

        if (current == State.EXECUTED) {
            revert Replay();
        }

        if (current == State.CANCELLED) {
            revert Cancelled();
        }

        if (block.timestamp > auth.deadline) {
            state[
                auth.agent
            ][
                auth.lane
            ][
                auth.nonce
            ] = State.EXPIRED;

            revert Expired();
        }

        address signer =
            hashAuthorization(auth).recover(signature);

        if (signer != auth.agent) {
            revert InvalidSigner();
        }

        state[
            auth.agent
        ][
            auth.lane
        ][
            auth.nonce
        ] = State.CANCELLED;
    }
}


contract Attack_AuthorizationReplayLifecycleTest is Test {

    AuthorizationReplayHarness internal auth;

    uint256 internal constant AGENT_KEY =
        0xA11CE;

    uint256 internal constant ATTACKER_KEY =
        0xB0B;

    uint256 internal constant SECOND_AGENT_KEY =
        0xBEEF;

    address internal agent;
    address internal attacker;

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
            new AuthorizationReplayHarness();

        agent =
            vm.addr(AGENT_KEY);

        attacker =
            vm.addr(ATTACKER_KEY);
    }

    function _auth(
        bytes32 lane,
        uint256 nonce,
        uint256 lifetime
    )
        internal
        view
        returns (
            AuthorizationReplayHarness.Authorization memory
        )
    {
        return
            AuthorizationReplayHarness.Authorization({
                agent: agent,
                lane: lane,
                nonce: nonce,
                deadline:
                    block.timestamp + lifetime
            });
    }

    function _signWithKey(
        uint256 privateKey,
        AuthorizationReplayHarness.Authorization memory authorization
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

    function _sign(
        AuthorizationReplayHarness.Authorization memory authorization
    )
        internal
        view
        returns (bytes memory)
    {
        return _signWithKey(
            AGENT_KEY,
            authorization
        );
    }

    /*
     * ============================================================
     * BASIC REPLAY
     * ============================================================
     */

    function test_SameSignatureCannotExecuteTwice()
        public
    {
        AuthorizationReplayHarness.Authorization memory authorization =
            _auth(
                PAYMENT_LANE,
                1,
                1 hours
            );

        bytes memory signature =
            _sign(authorization);

        auth.execute(
            authorization,
            signature
        );

        vm.expectRevert(
            AuthorizationReplayHarness.Replay.selector
        );

        auth.execute(
            authorization,
            signature
        );

        assertEq(
            uint256(
                auth.state(
                    agent,
                    PAYMENT_LANE,
                    1
                )
            ),
            uint256(
                AuthorizationReplayHarness.State.EXECUTED
            )
        );
    }

    /*
     * ============================================================
     * LOW-LEVEL REPLAY
     * ============================================================
     */

    function test_RawReplayCallFails()
        public
    {
        AuthorizationReplayHarness.Authorization memory authorization =
            _auth(
                PAYMENT_LANE,
                1,
                1 hours
            );

        bytes memory signature =
            _sign(authorization);

        auth.execute(
            authorization,
            signature
        );

        (
            bool success,
            bytes memory returndata
        ) =
            address(auth).call(
                abi.encodeCall(
                    AuthorizationReplayHarness.execute,
                    (
                        authorization,
                        signature
                    )
                )
            );

        assertFalse(
            success,
            "CRITICAL: replay succeeded"
        );

        assertEq(
            bytes4(returndata),
            AuthorizationReplayHarness.Replay.selector
        );
    }

    /*
     * ============================================================
     * ATTACKER REPLAY
     * ============================================================
     */

    function test_AttackerCannotReplayConsumedAuthorization()
        public
    {
        AuthorizationReplayHarness.Authorization memory authorization =
            _auth(
                PAYMENT_LANE,
                1,
                1 hours
            );

        bytes memory signature =
            _sign(authorization);

        auth.execute(
            authorization,
            signature
        );

        vm.prank(attacker);

        vm.expectRevert(
            AuthorizationReplayHarness.Replay.selector
        );

        auth.execute(
            authorization,
            signature
        );
    }

    /*
     * ============================================================
     * CANCEL BEFORE EXECUTION
     * ============================================================
     */

    function test_CancelledAuthorizationCannotExecute()
        public
    {
        AuthorizationReplayHarness.Authorization memory authorization =
            _auth(
                PAYMENT_LANE,
                1,
                1 hours
            );

        bytes memory signature =
            _sign(authorization);

        auth.cancel(
            authorization,
            signature
        );

        vm.expectRevert(
            AuthorizationReplayHarness.Cancelled.selector
        );

        auth.execute(
            authorization,
            signature
        );

        assertEq(
            uint256(
                auth.state(
                    agent,
                    PAYMENT_LANE,
                    1
                )
            ),
            uint256(
                AuthorizationReplayHarness.State.CANCELLED
            )
        );
    }

    /*
     * ============================================================
     * EXECUTION BEFORE CANCELLATION
     * ============================================================
     */

    function test_ExecutedAuthorizationCannotBeCancelled()
        public
    {
        AuthorizationReplayHarness.Authorization memory authorization =
            _auth(
                PAYMENT_LANE,
                1,
                1 hours
            );

        bytes memory signature =
            _sign(authorization);

        auth.execute(
            authorization,
            signature
        );

        vm.expectRevert(
            AuthorizationReplayHarness.Replay.selector
        );

        auth.cancel(
            authorization,
            signature
        );

        assertEq(
            uint256(
                auth.state(
                    agent,
                    PAYMENT_LANE,
                    1
                )
            ),
            uint256(
                AuthorizationReplayHarness.State.EXECUTED
            )
        );
    }

    /*
     * ============================================================
     * EXPIRATION
     * ============================================================
     */

    function test_ExpiredAuthorizationCannotExecute()
        public
    {
        AuthorizationReplayHarness.Authorization memory authorization =
            _auth(
                PAYMENT_LANE,
                1,
                1
            );

        bytes memory signature =
            _sign(authorization);

        vm.warp(
            authorization.deadline + 1
        );

        vm.expectRevert(
            AuthorizationReplayHarness.Expired.selector
        );

        auth.execute(
            authorization,
            signature
        );

        /*
         * execute() attempted to write EXPIRED and then reverted.
         *
         * Because EVM reverts are atomic, that state write is
         * rolled back. The authorization therefore remains NONE
         * in storage even though it is logically expired by time.
         */
        assertEq(
            uint256(
                auth.state(
                    agent,
                    PAYMENT_LANE,
                    1
                )
            ),
            uint256(
                AuthorizationReplayHarness.State.NONE
            )
        );
    }

    /*
     * ============================================================
     * EXPIRATION DOES NOT CREATE EXECUTION
     * ============================================================
     */

    function test_ExpiredAuthorizationNeverBecomesExecuted()
        public
    {
        AuthorizationReplayHarness.Authorization memory authorization =
            _auth(
                PAYMENT_LANE,
                1,
                1
            );

        bytes memory signature =
            _sign(authorization);

        vm.warp(
            authorization.deadline + 1
        );

        vm.expectRevert(
            AuthorizationReplayHarness.Expired.selector
        );

        auth.execute(
            authorization,
            signature
        );

        assertTrue(
            uint256(
                auth.state(
                    agent,
                    PAYMENT_LANE,
                    1
                )
            ) !=
            uint256(
                AuthorizationReplayHarness.State.EXECUTED
            )
        );
    }

    /*
     * ============================================================
     * FRESH NONCE AFTER EXPIRATION
     * ============================================================
     */

    function test_FreshNonceRemainsUsable()
        public
    {
        AuthorizationReplayHarness.Authorization memory expired =
            _auth(
                PAYMENT_LANE,
                1,
                1
            );

        vm.warp(
            expired.deadline + 1
        );

        bytes memory expiredSignature =
            _sign(expired);

        vm.expectRevert(
            AuthorizationReplayHarness.Expired.selector
        );

        auth.execute(
            expired,
            expiredSignature
        );

        AuthorizationReplayHarness.Authorization memory fresh =
            _auth(
                PAYMENT_LANE,
                2,
                1 hours
            );

        auth.execute(
            fresh,
            _sign(fresh)
        );

        assertEq(
            uint256(
                auth.state(
                    agent,
                    PAYMENT_LANE,
                    2
                )
            ),
            uint256(
                AuthorizationReplayHarness.State.EXECUTED
            )
        );
    }

    /*
     * ============================================================
     * NONCE ISOLATION
     * ============================================================
     */

    function test_ConsumedNonceDoesNotConsumeAnotherNonce()
        public
    {
        AuthorizationReplayHarness.Authorization memory first =
            _auth(
                PAYMENT_LANE,
                1,
                1 hours
            );

        AuthorizationReplayHarness.Authorization memory second =
            _auth(
                PAYMENT_LANE,
                2,
                1 hours
            );

        auth.execute(
            first,
            _sign(first)
        );

        auth.execute(
            second,
            _sign(second)
        );

        assertEq(
            uint256(
                auth.state(
                    agent,
                    PAYMENT_LANE,
                    1
                )
            ),
            uint256(
                AuthorizationReplayHarness.State.EXECUTED
            )
        );

        assertEq(
            uint256(
                auth.state(
                    agent,
                    PAYMENT_LANE,
                    2
                )
            ),
            uint256(
                AuthorizationReplayHarness.State.EXECUTED
            )
        );
    }

    /*
     * ============================================================
     * LANE ISOLATION
     * ============================================================
     */

    function test_LanesDoNotShareReplayState()
        public
    {
        AuthorizationReplayHarness.Authorization memory payment =
            _auth(
                PAYMENT_LANE,
                1,
                1 hours
            );

        AuthorizationReplayHarness.Authorization memory escrow =
            _auth(
                ESCROW_LANE,
                1,
                1 hours
            );

        auth.execute(
            payment,
            _sign(payment)
        );

        auth.execute(
            escrow,
            _sign(escrow)
        );

        assertEq(
            uint256(
                auth.state(
                    agent,
                    PAYMENT_LANE,
                    1
                )
            ),
            uint256(
                AuthorizationReplayHarness.State.EXECUTED
            )
        );

        assertEq(
            uint256(
                auth.state(
                    agent,
                    ESCROW_LANE,
                    1
                )
            ),
            uint256(
                AuthorizationReplayHarness.State.EXECUTED
            )
        );
    }

    /*
     * ============================================================
     * CROSS-AGENT STATE ISOLATION
     * ============================================================
     */

    function test_AgentStateIsIndependent()
        public
    {
        address secondAgent =
            vm.addr(
                SECOND_AGENT_KEY
            );

        AuthorizationReplayHarness.Authorization memory first =
            AuthorizationReplayHarness.Authorization({
                agent: agent,
                lane: PAYMENT_LANE,
                nonce: 1,
                deadline: block.timestamp + 1 hours
            });

        AuthorizationReplayHarness.Authorization memory second =
            AuthorizationReplayHarness.Authorization({
                agent: secondAgent,
                lane: PAYMENT_LANE,
                nonce: 1,
                deadline: block.timestamp + 1 hours
            });

        assertTrue(
            first.agent != second.agent,
            "agents unexpectedly equal"
        );

        bytes memory firstSignature =
            _signWithKey(
                AGENT_KEY,
                first
            );

        bytes memory secondSignature =
            _signWithKey(
                SECOND_AGENT_KEY,
                second
            );

        auth.execute(
            first,
            firstSignature
        );

        auth.execute(
            second,
            secondSignature
        );

        assertEq(
            uint256(
                auth.state(
                    agent,
                    PAYMENT_LANE,
                    1
                )
            ),
            uint256(
                AuthorizationReplayHarness.State.EXECUTED
            )
        );

        assertEq(
            uint256(
                auth.state(
                    secondAgent,
                    PAYMENT_LANE,
                    1
                )
            ),
            uint256(
                AuthorizationReplayHarness.State.EXECUTED
            )
        );
    }

    /*
     * ============================================================
     * SIGNATURE CANNOT RESURRECT EXPIRED AUTHORIZATION
     * ============================================================
     */

    function test_ExpiredSignatureCannotBeResurrected()
        public
    {
        AuthorizationReplayHarness.Authorization memory authorization =
            _auth(
                PAYMENT_LANE,
                1,
                1
            );

        bytes memory signature =
            _sign(authorization);

        vm.warp(
            authorization.deadline + 1
        );

        vm.expectRevert(
            AuthorizationReplayHarness.Expired.selector
        );

        auth.execute(
            authorization,
            signature
        );

        /*
         * Move time forward again.
         * Expiration is terminal; time cannot resurrect the authorization.
         */
        vm.warp(
            block.timestamp + 30 days
        );

        vm.expectRevert(
            AuthorizationReplayHarness.Expired.selector
        );

        auth.execute(
            authorization,
            signature
        );
    }
}
