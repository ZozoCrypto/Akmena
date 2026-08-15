// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaCore} from "../../src/core/AkmenaCore.sol";
import {AkmenaPolicyBoundary} from "../../src/authorization/AkmenaPolicyBoundary.sol";
import {EscrowEngine} from "../../src/economics/EscrowEngine.sol";

contract DummyTarget {
    function ping() external returns (bool) {
        return true;
    }
}

contract AkmenaPolicyBoundaryUnitTest is Test {
    AkmenaCore core;
    AkmenaPolicyBoundary boundary;
    EscrowEngine escrow;
    DummyTarget target;

    address humanOperator = address(0x111);
    address aiAgentHotWallet = address(0x222);

    function setUp() public {
        core = new AkmenaCore();
        escrow = new EscrowEngine();
        boundary = new AkmenaPolicyBoundary(address(core));
        target = new DummyTarget();

        vm.prank(address(this));
        core.registerModule(bytes32("ESCROW_ENGINE"), address(escrow), "2.1.0");
    }

    function test_SetAndExecutePolicy() public {
        // Human sets the policy
        vm.prank(humanOperator);
        boundary.setAgentPolicy(aiAgentHotWallet, 100e18, 1000e18, false);

        // Agent executes within the policy atomically
        vm.prank(aiAgentHotWallet);
        boundary.executeAgentCall(
            humanOperator, address(target), 50e18, 0, abi.encodeWithSelector(DummyTarget.ping.selector)
        );
    }
}
