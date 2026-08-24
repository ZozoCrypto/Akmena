// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

contract AuthorizationLifecycleHarness {

    enum State {
        NONE,
        EXECUTED,
        CANCELLED,
        EXPIRED
    }

    struct Intent {
        address agent;
        bytes32 lane;
        uint256 nonce;
        address target;
        uint256 amount;
        uint256 deadline;
    }

    mapping(
        address =>
        mapping(bytes32 =>
        mapping(uint256 => State))
    )
    public state;


    error AlreadyExecuted();
    error AlreadyCancelled();
    error AlreadyExpired();
    error InvalidState();


    function execute(
        Intent calldata intent
    )
        external
    {
        State current =
            state[
                intent.agent
            ][
                intent.lane
            ][
                intent.nonce
            ];


        if (
            current == State.EXECUTED
        ) {
            revert AlreadyExecuted();
        }


        if (
            current == State.CANCELLED
        ) {
            revert AlreadyCancelled();
        }


        if (
            block.timestamp > intent.deadline
        ) {
            state[
                intent.agent
            ][
                intent.lane
            ][
                intent.nonce
            ] =
                State.EXPIRED;

            revert AlreadyExpired();
        }


        if (
            current != State.NONE
        ) {
            revert InvalidState();
        }


        state[
            intent.agent
        ][
            intent.lane
        ][
            intent.nonce
        ] =
            State.EXECUTED;
    }


    function cancel(
        Intent calldata intent
    )
        external
    {
        State current =
            state[
                intent.agent
            ][
                intent.lane
            ][
                intent.nonce
            ];


        if (
            current == State.EXECUTED
        ) {
            revert AlreadyExecuted();
        }


        if (
            current == State.CANCELLED
        ) {
            revert AlreadyCancelled();
        }


        if (
            block.timestamp > intent.deadline
        ) {
            state[
                intent.agent
            ][
                intent.lane
            ][
                intent.nonce
            ] =
                State.EXPIRED;

            revert AlreadyExpired();
        }


        if (
            current != State.NONE
        ) {
            revert InvalidState();
        }


        state[
            intent.agent
        ][
            intent.lane
        ][
            intent.nonce
        ] =
            State.CANCELLED;
    }
}


contract Attack_AuthorizationLifecycleTest is Test {


    AuthorizationLifecycleHarness internal auth;


    address internal constant AGENT =
        address(0xA11CE);


    bytes32 internal constant PAYMENT =
        keccak256(
            "akmena.payment"
        );


    address internal constant TARGET =
        address(0xAAAA);



    function setUp()
        public
    {
        auth =
            new AuthorizationLifecycleHarness();
    }



    function _intent(
        uint256 nonce
    )
        internal
        view
        returns (
            AuthorizationLifecycleHarness.Intent memory
        )
    {
        return
            AuthorizationLifecycleHarness.Intent({
                agent: AGENT,
                lane: PAYMENT,
                nonce: nonce,
                target: TARGET,
                amount: 1 ether,
                deadline:
                    block.timestamp + 1 hours
            });
    }



    function test_PendingExecutesOnce()
        public
    {
        AuthorizationLifecycleHarness.Intent memory intent = _intent(1);

        auth.execute(intent);

        assertEq(
            uint256(
                auth.state(
                    AGENT,
                    PAYMENT,
                    1
                )
            ),
            uint256(
                AuthorizationLifecycleHarness.State.EXECUTED
            )
        );
    }



    function test_ExecutedCannotCancel()
        public
    {
        AuthorizationLifecycleHarness.Intent memory intent = _intent(1);

        auth.execute(intent);


        vm.expectRevert(
            AuthorizationLifecycleHarness.AlreadyExecuted.selector
        );


        auth.cancel(intent);
    }



    function test_CancelledCannotExecute()
        public
    {
        AuthorizationLifecycleHarness.Intent memory intent = _intent(1);

        auth.cancel(intent);


        vm.expectRevert(
            AuthorizationLifecycleHarness.AlreadyCancelled.selector
        );


        auth.execute(intent);
    }



    function test_DoubleExecuteRejected()
        public
    {
        AuthorizationLifecycleHarness.Intent memory intent = _intent(1);

        auth.execute(intent);


        vm.expectRevert(
            AuthorizationLifecycleHarness.AlreadyExecuted.selector
        );


        auth.execute(intent);
    }



    function test_DoubleCancelRejected()
        public
    {
        AuthorizationLifecycleHarness.Intent memory intent = _intent(1);

        auth.cancel(intent);


        vm.expectRevert(
            AuthorizationLifecycleHarness.AlreadyCancelled.selector
        );


        auth.cancel(intent);
    }



    function test_ExpiredIntentTerminal()
        public
    {
        AuthorizationLifecycleHarness.Intent memory intent = _intent(1);

        vm.warp(
            intent.deadline + 1
        );


        vm.expectRevert(
            AuthorizationLifecycleHarness.AlreadyExpired.selector
        );


        auth.execute(intent);


        assertEq(
            uint256(
                auth.state(
                    AGENT,
                    PAYMENT,
                    1
                )
            ),
            uint256(
                AuthorizationLifecycleHarness.State.EXPIRED
            )
        );
    }



    function test_NoncesAreIndependent()
        public
    {
        AuthorizationLifecycleHarness.Intent memory first =
            _intent(1);

        AuthorizationLifecycleHarness.Intent memory second =
            _intent(2);


        auth.execute(first);
        auth.cancel(second);


        assertEq(
            uint256(auth.state(
                AGENT,
                PAYMENT,
                1
            )),
            uint256(
                AuthorizationLifecycleHarness.State.EXECUTED
            )
        );


        assertEq(
            uint256(auth.state(
                AGENT,
                PAYMENT,
                2
            )),
            uint256(
                AuthorizationLifecycleHarness.State.CANCELLED
            )
        );
    }



    function test_LanesAreIndependent()
        public
    {
        AuthorizationLifecycleHarness.Intent memory payment =
            _intent(1);

        bytes32 escrow =
            keccak256(
                "akmena.escrow"
            );

        AuthorizationLifecycleHarness.Intent memory other =
            AuthorizationLifecycleHarness.Intent({
                agent: AGENT,
                lane: escrow,
                nonce: 1,
                target: TARGET,
                amount: 1 ether,
                deadline: payment.deadline
            });

        assertTrue(
            payment.lane != other.lane,
            "lanes unexpectedly equal"
        );

        auth.execute(payment);
        auth.cancel(other);

        assertEq(
            uint256(
                auth.state(
                    AGENT,
                    PAYMENT,
                    1
                )
            ),
            uint256(
                AuthorizationLifecycleHarness.State.EXECUTED
            )
        );

        assertEq(
            uint256(
                auth.state(
                    AGENT,
                    escrow,
                    1
                )
            ),
            uint256(
                AuthorizationLifecycleHarness.State.CANCELLED
            )
        );
    }
}
