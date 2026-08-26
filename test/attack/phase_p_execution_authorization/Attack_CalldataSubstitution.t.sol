// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaCore} from "../../../src/core/AkmenaCore.sol";
import {AkmenaPolicyBoundary} from "../../../src/authorization/AkmenaPolicyBoundary.sol";

contract CalldataTarget {

    address public lastRecipient;
    uint256 public lastAmount;

    function transferValue(
        address recipient,
        uint256 amount
    )
        external
    {
        lastRecipient = recipient;
        lastAmount = amount;
    }
}

contract Attack_CalldataSubstitutionTest is Test {

    AkmenaCore internal core;
    AkmenaPolicyBoundary internal boundary;
    CalldataTarget internal target;

    address internal operator =
        address(0x1111);

    address internal agent =
        address(0x2222);

    address internal authorizedRecipient =
        address(0xAAAA);

    address internal attackerRecipient =
        address(0xBBBB);

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
            new CalldataTarget();

        vm.prank(operator);

        boundary.setAgentPolicy(
            agent,
            1 ether,
            1 ether,
            false
        );
    }

    function test_Attack_CalldataIsNotBoundToAuthorization()
        public
    {
        /*
         * Conceptual authorized intent:
         *
         * transferValue(authorizedRecipient, 1 ether)
         */
        bytes memory authorizedPayload =
            abi.encodeWithSelector(
                CalldataTarget.transferValue.selector,
                authorizedRecipient,
                1 ether
            );

        /*
         * Prove the intended calldata executes.
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

        assertEq(
            target.lastRecipient(),
            authorizedRecipient,
            "authorized recipient did not execute"
        );

        assertEq(
            target.lastAmount(),
            1 ether,
            "authorized amount did not execute"
        );

        /*
         * Keep the SAME:
         *
         *   agent
         *   operator
         *   target
         *   selector
         *
         * but substitute the calldata arguments.
         */
        bytes memory substitutedPayload =
            abi.encodeWithSelector(
                CalldataTarget.transferValue.selector,
                attackerRecipient,
                100 ether
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
         * If these assertions pass, the real boundary
         * accepted calldata substitution.
         */
        assertEq(
            target.lastRecipient(),
            attackerRecipient,
            "calldata recipient substitution was blocked"
        );

        assertEq(
            target.lastAmount(),
            100 ether,
            "calldata amount substitution was blocked"
        );
    }
}
