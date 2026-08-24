// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

contract NonceStateNoCrypto {

    mapping(address => mapping(bytes32 => mapping(uint256 => bool)))
        public used;

    mapping(address => mapping(bytes32 => mapping(uint256 => bool)))
        public cancelled;

    error Replay();
    error Cancelled();

    function execute(
        address agent,
        bytes32 lane,
        uint256 nonce
    )
        external
    {
        if (
            cancelled[agent][lane][nonce]
        ) {
            revert Cancelled();
        }

        if (
            used[agent][lane][nonce]
        ) {
            revert Replay();
        }

        used[agent][lane][nonce] = true;
    }

    function cancel(
        address agent,
        bytes32 lane,
        uint256 nonce
    )
        external
    {
        if (
            cancelled[agent][lane][nonce]
        ) {
            revert Cancelled();
        }

        if (
            used[agent][lane][nonce]
        ) {
            revert Replay();
        }

        cancelled[agent][lane][nonce] = true;
    }
}

contract Attack_NonceStateNoCryptoTest is Test {

    NonceStateNoCrypto internal auth;

    address internal constant AGENT =
        address(0xA11CE);

    bytes32 internal constant PAYMENT_LANE =
        keccak256("akmena.lane.payment");

    function setUp() public {
        auth = new NonceStateNoCrypto();
    }

    function test_ExecutionConsumesNonce()
        public
    {
        auth.execute(
            AGENT,
            PAYMENT_LANE,
            1
        );

        assertTrue(
            auth.used(
                AGENT,
                PAYMENT_LANE,
                1
            )
        );
    }

    function test_DoubleExecutionReverts()
        public
    {
        auth.execute(
            AGENT,
            PAYMENT_LANE,
            1
        );

        vm.expectRevert(
            NonceStateNoCrypto.Replay.selector
        );

        auth.execute(
            AGENT,
            PAYMENT_LANE,
            1
        );
    }

    function test_CancellationConsumesNonce()
        public
    {
        auth.cancel(
            AGENT,
            PAYMENT_LANE,
            1
        );

        assertTrue(
            auth.cancelled(
                AGENT,
                PAYMENT_LANE,
                1
            )
        );
    }

    function test_CancelledBlocksExecution()
        public
    {
        auth.cancel(
            AGENT,
            PAYMENT_LANE,
            1
        );

        vm.expectRevert(
            NonceStateNoCrypto.Cancelled.selector
        );

        auth.execute(
            AGENT,
            PAYMENT_LANE,
            1
        );
    }

    function test_UsedBlocksCancellation()
        public
    {
        auth.execute(
            AGENT,
            PAYMENT_LANE,
            1
        );

        vm.expectRevert(
            NonceStateNoCrypto.Replay.selector
        );

        auth.cancel(
            AGENT,
            PAYMENT_LANE,
            1
        );
    }

    function test_LanesAreIndependent()
        public
    {
        auth.execute(
            AGENT,
            PAYMENT_LANE,
            1
        );

        bytes32 escrowLane =
            keccak256("akmena.lane.escrow");

        auth.cancel(
            AGENT,
            escrowLane,
            1
        );

        assertTrue(
            auth.used(
                AGENT,
                PAYMENT_LANE,
                1
            )
        );

        assertTrue(
            auth.cancelled(
                AGENT,
                escrowLane,
                1
            )
        );
    }

    function test_NoncesAreIndependent()
        public
    {
        auth.execute(
            AGENT,
            PAYMENT_LANE,
            1
        );

        auth.execute(
            AGENT,
            PAYMENT_LANE,
            2
        );

        assertTrue(
            auth.used(
                AGENT,
                PAYMENT_LANE,
                1
            )
        );

        assertTrue(
            auth.used(
                AGENT,
                PAYMENT_LANE,
                2
            )
        );
    }

    function test_RawSecondExecutionReverts()
        public
    {
        auth.execute(
            AGENT,
            PAYMENT_LANE,
            1
        );

        (
            bool success,
            bytes memory returndata
        ) =
            address(auth).call(
                abi.encodeCall(
                    NonceStateNoCrypto.execute,
                    (
                        AGENT,
                        PAYMENT_LANE,
                        1
                    )
                )
            );

        assertFalse(success);

        assertEq(
            bytes4(returndata),
            NonceStateNoCrypto.Replay.selector
        );
    }
}
