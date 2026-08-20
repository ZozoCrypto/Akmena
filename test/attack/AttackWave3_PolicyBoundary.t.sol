// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaCore} from "../../src/core/AkmenaCore.sol";
import {AkmenaPolicyBoundary} from "../../src/authorization/AkmenaPolicyBoundary.sol";
import {EscrowEngine} from "../../src/economics/EscrowEngine.sol";

contract AttackWave3_PolicyBoundaryTest is Test {
    AkmenaCore internal core;
    AkmenaPolicyBoundary internal boundary;
    EscrowEngine internal escrow;

    address internal operator = address(0x1111);
    address internal agent = address(0x2222);
    address internal attacker = address(0xBEEF);

    function setUp() public {
        core = new AkmenaCore();
        escrow = new EscrowEngine();
        boundary = new AkmenaPolicyBoundary(address(core));

        vm.prank(address(this));
        core.registerModule(bytes32("ESCROW_ENGINE"), address(escrow), "2.1.0");

        vm.prank(operator);
        boundary.setAgentPolicy(agent, 100 ether, 1_000 ether, false);
    }

    function test_Attack_UnauthorizedCallerCannotConsumeVictimDailyLimit() public {
        vm.prank(attacker);

        vm.expectRevert(AkmenaPolicyBoundary.UnauthorizedAgent.selector);
        boundary.executeAgentCall(
            operator,
            address(this), // Dummy target
            100 ether, bytes32("ESCROW_ENGINE"),
            0,
            "" // Empty payload
        );
    }

    function test_Attack_EscrowRequirementCannotBeSatisfiedByMissingEscrow() public {
        vm.prank(operator);
        boundary.setAgentPolicy(agent, 100 ether, 1_000 ether, true);

        vm.prank(agent);
        vm.expectRevert();
        boundary.executeAgentCall(operator, address(this), 1 ether, bytes32("ESCROW_ENGINE"), 999999, "");
    }

    function test_Attack_ArbitraryCallerCanSubmitVictimIdentity() public {
        vm.prank(attacker);

        vm.expectRevert(AkmenaPolicyBoundary.UnauthorizedAgent.selector);
        boundary.executeAgentCall(operator, address(this), 1 ether, bytes32("ESCROW_ENGINE"), 0, "");
    }
}
