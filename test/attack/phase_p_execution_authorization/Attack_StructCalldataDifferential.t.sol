// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

contract StructCalldataHarness {

    struct Intent {
        address agent;
        bytes32 lane;
        uint256 nonce;
        address target;
        uint256 amount;
        uint256 deadline;
    }

    mapping(address => mapping(bytes32 => mapping(uint256 => bool)))
        public used;

    mapping(address => mapping(bytes32 => mapping(uint256 => bool)))
        public cancelled;

    error Replay();
    error Cancelled();

    function execute(
        Intent calldata intent
    )
        external
    {
        if (
            cancelled[
                intent.agent
            ][
                intent.lane
            ][
                intent.nonce
            ]
        ) {
            revert Cancelled();
        }

        if (
            used[
                intent.agent
            ][
                intent.lane
            ][
                intent.nonce
            ]
        ) {
            revert Replay();
        }

        used[
            intent.agent
        ][
            intent.lane
        ][
            intent.nonce
        ] = true;
    }

    function cancel(
        Intent calldata intent
    )
        external
    {
        if (
            cancelled[
                intent.agent
            ][
                intent.lane
            ][
                intent.nonce
            ]
        ) {
            revert Cancelled();
        }

        if (
            used[
                intent.agent
            ][
                intent.lane
            ][
                intent.nonce
            ]
        ) {
            revert Replay();
        }

        cancelled[
            intent.agent
        ][
            intent.lane
        ][
            intent.nonce
        ] = true;
    }
}

contract Attack_StructCalldataDifferentialTest is Test {

    StructCalldataHarness internal auth;

    address internal constant AGENT =
        address(0xA11CE);

    bytes32 internal constant LANE =
        keccak256("akmena.lane.payment");

    address internal constant TARGET =
        address(0xAAAA);

    function setUp() public {
        auth = new StructCalldataHarness();
    }

    function _intent(
        uint256 nonce
    )
        internal
        view
        returns (
            StructCalldataHarness.Intent memory
        )
    {
        return StructCalldataHarness.Intent({
            agent: AGENT,
            lane: LANE,
            nonce: nonce,
            target: TARGET,
            amount: 1 ether,
            deadline: block.timestamp + 1 hours
        });
    }

    function test_ExecuteConsumesStructNonce()
        public
    {
        StructCalldataHarness.Intent memory intent =
            _intent(1);

        auth.execute(intent);

        assertTrue(
            auth.used(
                AGENT,
                LANE,
                1
            )
        );
    }

    function test_ExecutedStructCannotCancel()
        public
    {
        StructCalldataHarness.Intent memory intent =
            _intent(1);

        auth.execute(intent);

        vm.expectRevert(
            StructCalldataHarness.Replay.selector
        );

        auth.cancel(intent);
    }

    function test_CancelledStructCannotExecute()
        public
    {
        StructCalldataHarness.Intent memory intent =
            _intent(1);

        auth.cancel(intent);

        vm.expectRevert(
            StructCalldataHarness.Cancelled.selector
        );

        auth.execute(intent);
    }

    function test_LowLevelStructReplay()
        public
    {
        StructCalldataHarness.Intent memory intent =
            _intent(1);

        auth.execute(intent);

        (
            bool success,
            bytes memory returndata
        ) =
            address(auth).call(
                abi.encodeCall(
                    StructCalldataHarness.execute,
                    (intent)
                )
            );

        assertFalse(success);

        assertEq(
            bytes4(returndata),
            StructCalldataHarness.Replay.selector
        );
    }

    function test_SeparateStructInstances()
        public
    {
        StructCalldataHarness.Intent memory first =
            _intent(1);

        StructCalldataHarness.Intent memory second =
            _intent(1);

        auth.execute(first);

        vm.expectRevert(
            StructCalldataHarness.Replay.selector
        );

        auth.execute(second);
    }

    function test_DifferentNonceWithSameStructShape()
        public
    {
        StructCalldataHarness.Intent memory first =
            _intent(1);

        StructCalldataHarness.Intent memory second =
            _intent(2);

        auth.execute(first);
        auth.execute(second);

        assertTrue(
            auth.used(
                AGENT,
                LANE,
                1
            )
        );

        assertTrue(
            auth.used(
                AGENT,
                LANE,
                2
            )
        );
    }
}
