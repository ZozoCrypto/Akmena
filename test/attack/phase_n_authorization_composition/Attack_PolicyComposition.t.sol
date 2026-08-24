// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaCore} from "../../../src/core/AkmenaCore.sol";
import {AkmenaPolicyBoundary} from "../../../src/authorization/AkmenaPolicyBoundary.sol";

contract PhaseNTarget {
    uint256 public calls;
    uint256 public valueReceived;
    bytes32 public lastData;

    function action(uint256 value) external {
        calls++;
        valueReceived += value;
        lastData = keccak256(msg.data);
    }

    function privileged() external {
        calls++;
        lastData = keccak256(msg.data);
    }
}

contract Attack_PolicyCompositionTest is Test {
    AkmenaCore internal core;
    AkmenaPolicyBoundary internal boundary;
    PhaseNTarget internal target;

    address internal operator = address(0x1111);
    address internal agent = address(0x2222);
    address internal attacker = address(0x3333);

    function setUp() public {
        core = new AkmenaCore();
        boundary = new AkmenaPolicyBoundary(address(core));
        target = new PhaseNTarget();

        vm.prank(operator);
        boundary.setAgentPolicy(
            agent,
            1 ether,
            10 ether,
            false
        );
    }

    function test_Attack_OperatorSubstitution() public {
        vm.prank(agent);

        vm.expectRevert(
            AkmenaPolicyBoundary.UnauthorizedAgent.selector
        );

        boundary.executeAgentCall(
            attacker,
            address(target),
            1 ether,
            bytes32(0),
            0,
            abi.encodeWithSelector(
                PhaseNTarget.privileged.selector
            )
        );
    }

    function test_Attack_AgentSubstitution() public {
        vm.prank(attacker);

        vm.expectRevert(
            AkmenaPolicyBoundary.UnauthorizedAgent.selector
        );

        boundary.executeAgentCall(
            operator,
            address(target),
            1 ether,
            bytes32(0),
            0,
            abi.encodeWithSelector(
                PhaseNTarget.privileged.selector
            )
        );
    }

    function test_Attack_PolicyCanAuthorizeDifferentSelector() public {
        vm.prank(agent);

        boundary.executeAgentCall(
            operator,
            address(target),
            1 ether,
            bytes32(0),
            0,
            abi.encodeWithSelector(
                PhaseNTarget.privileged.selector
            )
        );

        assertEq(
            target.calls(),
            1,
            "Policy authorized execution"
        );
    }

    function test_Attack_PolicyCanAuthorizeDifferentCalldata() public {
        vm.prank(agent);

        boundary.executeAgentCall(
            operator,
            address(target),
            1 ether,
            bytes32(0),
            0,
            abi.encodeWithSelector(
                PhaseNTarget.action.selector,
                100 ether
            )
        );

        assertEq(
            target.valueReceived(),
            100 ether,
            "EXPECTED VULNERABILITY: calldata exceeds declared spend"
        );
    }

    function test_Attack_ZeroSpendCanExecute() public {
        vm.prank(agent);

        boundary.executeAgentCall(
            operator,
            address(target),
            0,
            bytes32(0),
            0,
            abi.encodeWithSelector(
                PhaseNTarget.privileged.selector
            )
        );

        assertEq(
            target.calls(),
            1,
            "Zero declared spend should not authorize arbitrary action"
        );
    }

    function test_Attack_PolicyIsNotBoundToTarget() public {
        PhaseNTarget secondTarget = new PhaseNTarget();

        vm.prank(agent);

        boundary.executeAgentCall(
            operator,
            address(secondTarget),
            1 ether,
            bytes32(0),
            0,
            abi.encodeWithSelector(
                PhaseNTarget.privileged.selector
            )
        );

        assertEq(
            secondTarget.calls(),
            1,
            "EXPECTED VULNERABILITY: policy is not target-bound"
        );
    }
}
