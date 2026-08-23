// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaCore} from "../../../src/core/AkmenaCore.sol";
import {AkmenaPolicyBoundary} from "../../../src/authorization/AkmenaPolicyBoundary.sol";

contract MultiActionTarget {
    uint256 public harmlessCalls;
    uint256 public dangerousValue;

    address public immutable trustedExecutor;

    constructor(address _trustedExecutor) {
        trustedExecutor = _trustedExecutor;
    }

    function harmlessAction() external {
        require(msg.sender == trustedExecutor, "NOT_TRUSTED_EXECUTOR");
        harmlessCalls++;
    }

    function dangerousAction(uint256 value) external {
        require(msg.sender == trustedExecutor, "NOT_TRUSTED_EXECUTOR");
        dangerousValue += value;
    }
}

contract Attack_PayloadSubstitutionTest is Test {
    AkmenaCore internal core;
    AkmenaPolicyBoundary internal boundary;
    MultiActionTarget internal target;

    address internal operator = address(0x1111);
    address internal agent = address(0x2222);

    function setUp() public {
        core = new AkmenaCore();
        boundary = new AkmenaPolicyBoundary(address(core));
        target = new MultiActionTarget(address(boundary));

        vm.prank(operator);
        boundary.setAgentPolicy(
            agent,
            1 ether,
            2 ether,
            false
        );
    }

    function test_Attack_PayloadCanSelectDifferentPrivilegedAction() public {
        bytes memory payload = abi.encodeWithSelector(
            MultiActionTarget.dangerousAction.selector,
            1_000_000
        );

        vm.prank(agent);

        boundary.executeAgentCall(
            operator,
            address(target),
            1 ether,
            bytes32(0),
            0,
            payload
        );

        assertEq(
            target.dangerousValue(),
            1_000_000,
            "CRITICAL: substituted privileged payload did not execute"
        );
    }

    function test_Attack_SamePolicyDoesNotBindFunctionSelector() public {
        bytes memory firstPayload = abi.encodeWithSelector(
            MultiActionTarget.harmlessAction.selector
        );

        vm.prank(agent);

        boundary.executeAgentCall(
            operator,
            address(target),
            1 ether,
            bytes32(0),
            0,
            firstPayload
        );

        bytes memory substitutedPayload = abi.encodeWithSelector(
            MultiActionTarget.dangerousAction.selector,
            999_999
        );

        vm.prank(agent);

        boundary.executeAgentCall(
            operator,
            address(target),
            1 ether,
            bytes32(0),
            0,
            substitutedPayload
        );

        assertEq(
            target.harmlessCalls(),
            1,
            "expected initial authorized action"
        );

        assertEq(
            target.dangerousValue(),
            999_999,
            "CRITICAL: function selector was not bound to authorization"
        );
    }
}
