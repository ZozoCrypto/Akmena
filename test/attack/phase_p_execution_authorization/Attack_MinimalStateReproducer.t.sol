// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

contract MinimalStateMachine {
    mapping(address => mapping(bytes32 => mapping(uint256 => bool)))
        public used;

    mapping(address => mapping(bytes32 => mapping(uint256 => bool)))
        public cancelled;

    error Replay();
    error Cancelled();

    function markUsed(
        address agent,
        bytes32 lane,
        uint256 nonce
    ) external {
        used[agent][lane][nonce] = true;
    }

    function markCancelled(
        address agent,
        bytes32 lane,
        uint256 nonce
    ) external {
        cancelled[agent][lane][nonce] = true;
    }

    function execute(
        address agent,
        bytes32 lane,
        uint256 nonce
    ) external {
        if (cancelled[agent][lane][nonce]) {
            revert Cancelled();
        }

        if (used[agent][lane][nonce]) {
            revert Replay();
        }

        used[agent][lane][nonce] = true;
    }

    function cancel(
        address agent,
        bytes32 lane,
        uint256 nonce
    ) external {
        if (cancelled[agent][lane][nonce]) {
            revert Cancelled();
        }

        if (used[agent][lane][nonce]) {
            revert Replay();
        }

        cancelled[agent][lane][nonce] = true;
    }
}

contract Attack_MinimalStateReproducerTest is Test {
    MinimalStateMachine internal state;

    address internal constant AGENT =
        address(0x1111);

    bytes32 internal constant LANE =
        keccak256("payment");

    function setUp() public {
        state = new MinimalStateMachine();
    }

    function test_CancelledBlocksExecution()
        public
    {
        state.markCancelled(
            AGENT,
            LANE,
            1
        );

        assertTrue(
            state.cancelled(
                AGENT,
                LANE,
                1
            )
        );

        vm.expectRevert(
            MinimalStateMachine.Cancelled.selector
        );

        state.execute(
            AGENT,
            LANE,
            1
        );
    }

    function test_UsedBlocksCancellation()
        public
    {
        state.markUsed(
            AGENT,
            LANE,
            1
        );

        assertTrue(
            state.used(
                AGENT,
                LANE,
                1
            )
        );

        vm.expectRevert(
            MinimalStateMachine.Replay.selector
        );

        state.cancel(
            AGENT,
            LANE,
            1
        );
    }

    function test_ExecutionConsumesState()
        public
    {
        state.execute(
            AGENT,
            LANE,
            1
        );

        assertTrue(
            state.used(
                AGENT,
                LANE,
                1
            )
        );

        vm.expectRevert(
            MinimalStateMachine.Replay.selector
        );

        state.execute(
            AGENT,
            LANE,
            1
        );
    }

    function test_CancellationConsumesState()
        public
    {
        state.cancel(
            AGENT,
            LANE,
            1
        );

        assertTrue(
            state.cancelled(
                AGENT,
                LANE,
                1
            )
        );

        vm.expectRevert(
            MinimalStateMachine.Cancelled.selector
        );

        state.cancel(
            AGENT,
            LANE,
            1
        );
    }
}
