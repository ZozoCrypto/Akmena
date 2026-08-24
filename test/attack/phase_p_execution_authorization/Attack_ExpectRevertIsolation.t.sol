// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

contract ExpectRevertHarness {

    uint256 public state;

    error AlreadyUsed();

    function consume()
        external
    {
        if (state == 1) {
            revert AlreadyUsed();
        }

        state = 1;
    }
}

contract Attack_ExpectRevertIsolationTest is Test {

    ExpectRevertHarness internal harness;

    function setUp() public {
        harness = new ExpectRevertHarness();
    }

    function test_ExpectRevertAfterStateMutation()
        public
    {
        harness.consume();

        assertEq(
            harness.state(),
            1
        );

        vm.expectRevert(
            ExpectRevertHarness.AlreadyUsed.selector
        );

        harness.consume();
    }

    function test_LowLevelCallAfterStateMutation()
        public
    {
        harness.consume();

        assertEq(
            harness.state(),
            1
        );

        (bool success, bytes memory returndata) =
            address(harness).call(
                abi.encodeCall(
                    ExpectRevertHarness.consume,
                    ()
                )
            );

        assertFalse(success);

        assertEq(
            bytes4(returndata),
            ExpectRevertHarness.AlreadyUsed.selector
        );
    }

    function test_ExpectRevertInsideHelper()
        public
    {
        harness.consume();

        _expectReplay();
    }

    function _expectReplay()
        internal
    {
        vm.expectRevert(
            ExpectRevertHarness.AlreadyUsed.selector
        );

        harness.consume();
    }

    function test_ExpectRevertAfterViewCall()
        public
    {
        harness.consume();

        assertEq(
            harness.state(),
            1
        );

        uint256 current =
            harness.state();

        assertEq(
            current,
            1
        );

        vm.expectRevert(
            ExpectRevertHarness.AlreadyUsed.selector
        );

        harness.consume();
    }
}
