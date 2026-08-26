// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaCore} from "../../../src/core/AkmenaCore.sol";
import {AkmenaPolicyBoundary} from "../../../src/authorization/AkmenaPolicyBoundary.sol";

contract AuthorizedTarget {

    bool public executed;

    function execute()
        external
    {
        executed = true;
    }
}

contract UnauthorizedTarget {

    bool public executed;

    function execute()
        external
    {
        executed = true;
    }
}

contract Attack_TargetSubstitutionTest is Test {

    AkmenaCore internal core;
    AkmenaPolicyBoundary internal boundary;

    AuthorizedTarget internal authorizedTarget;
    UnauthorizedTarget internal unauthorizedTarget;

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

        authorizedTarget =
            new AuthorizedTarget();

        unauthorizedTarget =
            new UnauthorizedTarget();

        vm.prank(operator);

        boundary.setAgentPolicy(
            agent,
            1 ether,
            1 ether,
            false
        );
    }

    function test_Attack_TargetIsNotBoundToPolicy()
        public
    {
        bytes memory payload =
            abi.encodeWithSelector(
                UnauthorizedTarget.execute.selector
            );

        vm.prank(agent);

        boundary.executeAgentCall(
            operator,
            address(unauthorizedTarget),
            0,
            bytes32(0),
            0,
            payload
        );

        assertTrue(
            unauthorizedTarget.executed(),
            "target substitution was unexpectedly blocked"
        );
    }
}
