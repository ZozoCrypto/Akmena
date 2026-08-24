// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaCore} from "../../../src/core/AkmenaCore.sol";
import {AkmenaPolicyBoundary} from "../../../src/authorization/AkmenaPolicyBoundary.sol";

contract PhaseOTarget {
    uint256 public calls;
    uint256 public amount;

    function execute(uint256 value) external {
        calls++;
        amount += value;
    }

    function privileged() external {
        calls++;
    }
}

contract Attack_ExecutionBindingTest is Test {
    AkmenaCore internal core;
    AkmenaPolicyBoundary internal boundary;
    PhaseOTarget internal targetA;
    PhaseOTarget internal targetB;

    address internal operator = address(0x1111);
    address internal agent = address(0x2222);

    function setUp() public {
        core = new AkmenaCore();
        boundary = new AkmenaPolicyBoundary(address(core));

        targetA = new PhaseOTarget();
        targetB = new PhaseOTarget();

        vm.prank(operator);
        boundary.setAgentPolicy(
            agent,
            1 ether,
            10 ether,
            false
        );
    }

    function test_Attack_TargetSubstitution() public {
        vm.prank(agent);

        boundary.executeAgentCall(
            operator,
            address(targetB),
            1 ether,
            bytes32(0),
            0,
            abi.encodeWithSelector(
                PhaseOTarget.privileged.selector
            )
        );

        assertEq(
            targetB.calls(),
            1,
            "EXPECTED VULNERABILITY: execution target is not bound"
        );
    }

    function test_Attack_SelectorSubstitution() public {
        vm.prank(agent);

        boundary.executeAgentCall(
            operator,
            address(targetA),
            1 ether,
            bytes32(0),
            0,
            abi.encodeWithSelector(
                PhaseOTarget.privileged.selector
            )
        );

        assertEq(
            targetA.calls(),
            1,
            "EXPECTED VULNERABILITY: selector is not bound"
        );
    }

    function test_Attack_CalldataSubstitution() public {
        vm.prank(agent);

        boundary.executeAgentCall(
            operator,
            address(targetA),
            1 ether,
            bytes32(0),
            0,
            abi.encodeWithSelector(
                PhaseOTarget.execute.selector,
                100 ether
            )
        );

        assertEq(
            targetA.amount(),
            100 ether,
            "EXPECTED VULNERABILITY: calldata is not bound"
        );
    }

    function test_Attack_ValueSubstitution() public {
        /*
         * The current boundary does not forward msg.value at all,
         * so this test documents the fact that native value is not
         * presently part of the authorization commitment.
         *
         * We use the declared spend amount to demonstrate that the
         * economic authorization is still independent from execution.
         */
        vm.prank(agent);

        boundary.executeAgentCall(
            operator,
            address(targetA),
            0,
            bytes32(0),
            0,
            abi.encodeWithSelector(
                PhaseOTarget.execute.selector,
                100 ether
            )
        );

        assertEq(
            targetA.amount(),
            100 ether,
            "EXPECTED VULNERABILITY: zero declared spend controls execution"
        );
    }

    function test_Attack_ReplaySameAuthorization() public {
        bytes memory payload =
            abi.encodeWithSelector(
                PhaseOTarget.privileged.selector
            );

        vm.startPrank(agent);

        boundary.executeAgentCall(
            operator,
            address(targetA),
            1 ether,
            bytes32(0),
            0,
            payload
        );

        boundary.executeAgentCall(
            operator,
            address(targetA),
            1 ether,
            bytes32(0),
            0,
            payload
        );

        vm.stopPrank();

        assertEq(
            targetA.calls(),
            2,
            "EXPECTED VULNERABILITY: authorization can be replayed"
        );
    }

    function test_Attack_ProofDomainCanChangeExecutionContext() public {
        bytes memory payload =
            abi.encodeWithSelector(
                PhaseOTarget.privileged.selector
            );

        vm.prank(agent);

        boundary.executeAgentCall(
            operator,
            address(targetA),
            1 ether,
            keccak256("ARBITRARY_DOMAIN_A"),
            0,
            payload
        );

        vm.prank(agent);

        boundary.executeAgentCall(
            operator,
            address(targetA),
            1 ether,
            keccak256("ARBITRARY_DOMAIN_B"),
            0,
            payload
        );

        assertEq(
            targetA.calls(),
            2,
            "EXPECTED VULNERABILITY: proof domain is not bound to execution"
        );
    }
}
