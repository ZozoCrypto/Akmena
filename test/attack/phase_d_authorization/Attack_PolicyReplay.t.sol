// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaCore} from "../../../src/core/AkmenaCore.sol";
import {AkmenaPolicyBoundary} from "../../../src/authorization/AkmenaPolicyBoundary.sol";

contract ReplayTarget {
    uint256 public executions;

    function execute() external {
        executions++;
    }
}

contract Attack_PolicyReplayTest is Test {
    AkmenaCore internal core;
    AkmenaPolicyBoundary internal boundary;
    ReplayTarget internal target;

    address internal operator = address(0x1111);
    address internal agent = address(0x2222);

    function setUp() public {
        core = new AkmenaCore();
        boundary = new AkmenaPolicyBoundary(address(core));
        target = new ReplayTarget();

        vm.prank(operator);
        boundary.setAgentPolicy(
            agent,
            1 ether,
            3 ether,
            false
        );
    }

    function test_Attack_IdenticalAuthorizedCallCanBeReplayed() public {
        bytes memory payload = abi.encodeWithSelector(
            ReplayTarget.execute.selector
        );

        vm.startPrank(agent);

        boundary.executeAgentCall(
            operator,
            address(target),
            1 ether,
            bytes32(0),
            0,
            payload
        );

        boundary.executeAgentCall(
            operator,
            address(target),
            1 ether,
            bytes32(0),
            0,
            payload
        );

        boundary.executeAgentCall(
            operator,
            address(target),
            1 ether,
            bytes32(0),
            0,
            payload
        );

        vm.stopPrank();

        assertEq(
            target.executions(),
            3,
            "CRITICAL: identical authorized call was not replayable"
        );
    }
}
