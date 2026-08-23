// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaCore} from "../../../src/core/AkmenaCore.sol";
import {AkmenaPolicyBoundary} from "../../../src/authorization/AkmenaPolicyBoundary.sol";

contract PrivilegedTarget {
    uint256 public privilegedState;

    function privilegedAction() external {
        privilegedState = 777;
    }
}

contract Attack_ArbitraryTargetAuthorizationTest is Test {
    AkmenaCore internal core;
    AkmenaPolicyBoundary internal boundary;
    PrivilegedTarget internal target;

    address internal operator = address(0x1111);
    address internal agent = address(0x2222);

    function setUp() public {
        core = new AkmenaCore();
        boundary = new AkmenaPolicyBoundary(address(core));
        target = new PrivilegedTarget();

        vm.prank(operator);
        boundary.setAgentPolicy(
            agent,
            1 ether,
            10 ether,
            false
        );
    }

    function test_Attack_AnyTargetCanBeSelectedByAuthorizedAgent() public {
        assertEq(target.privilegedState(), 0);

        vm.prank(agent);

        boundary.executeAgentCall(
            operator,
            address(target),
            0,
            bytes32(0),
            0,
            abi.encodeWithSelector(
                PrivilegedTarget.privilegedAction.selector
            )
        );

        assertEq(
            target.privilegedState(),
            777,
            "CRITICAL: arbitrary target was not executable"
        );
    }
}
