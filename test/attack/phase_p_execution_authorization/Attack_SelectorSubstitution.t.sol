// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaCore} from "../../../src/core/AkmenaCore.sol";
import {AkmenaPolicyBoundary} from "../../../src/authorization/AkmenaPolicyBoundary.sol";

contract SelectorTarget {

    bool public authorizedExecuted;
    bool public unauthorizedExecuted;

    function authorizedAction()
        external
    {
        authorizedExecuted = true;
    }

    function unauthorizedAction()
        external
    {
        unauthorizedExecuted = true;
    }
}

contract Attack_SelectorSubstitutionTest is Test {

    AkmenaCore internal core;
    AkmenaPolicyBoundary internal boundary;
    SelectorTarget internal target;

    address internal operator =
        address(0x1111);

    address internal agent =
        address(0x2222);

    function setUp()
        public
    {
        core =
            new AkmenaCore();

        boundary =
            new AkmenaPolicyBoundary(
                address(core)
            );

        target =
            new SelectorTarget();

        vm.prank(operator);

        boundary.setAgentPolicy(
            agent,
            1 ether,
            1 ether,
            false
        );
    }

    function test_Attack_SelectorIsNotBoundToPolicy()
        public
    {
        /*
         * The conceptual authorization is for
         * authorizedAction().
         */
        bytes memory authorizedPayload =
            abi.encodeWithSelector(
                SelectorTarget.authorizedAction.selector
            );

        /*
         * Prove the intended selector can execute.
         */
        vm.prank(agent);

        boundary.executeAgentCall(
            operator,
            address(target),
            0,
            bytes32(0),
            0,
            authorizedPayload
        );

        assertTrue(
            target.authorizedExecuted(),
            "authorized selector did not execute"
        );

        /*
         * Now substitute a DIFFERENT selector while
         * keeping the same target and agent.
         */
        bytes memory substitutedPayload =
            abi.encodeWithSelector(
                SelectorTarget.unauthorizedAction.selector
            );

        vm.prank(agent);

        boundary.executeAgentCall(
            operator,
            address(target),
            0,
            bytes32(0),
            0,
            substitutedPayload
        );

        /*
         * Diagnostic objective:
         *
         * If this assertion passes, the real boundary
         * accepted selector substitution.
         */
        assertTrue(
            target.unauthorizedExecuted(),
            "selector substitution was blocked"
        );
    }
}
