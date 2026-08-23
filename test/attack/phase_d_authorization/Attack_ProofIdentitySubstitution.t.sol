// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaCore} from "../../../src/core/AkmenaCore.sol";
import {AkmenaPolicyBoundary} from "../../../src/authorization/AkmenaPolicyBoundary.sol";
import {EscrowEngine} from "../../../src/economics/EscrowEngine.sol";

contract IdentityTarget {
    address public lastCaller;

    function execute() external {
        lastCaller = msg.sender;
    }
}

contract Attack_ProofIdentitySubstitutionTest is Test {
    AkmenaCore internal core;
    AkmenaPolicyBoundary internal boundary;
    EscrowEngine internal escrow;
    IdentityTarget internal target;

    address internal operator = address(0x1111);
    address internal agent = address(0x2222);
    address internal attacker = address(0xBEEF);

    function setUp() public {
        core = new AkmenaCore();
        boundary = new AkmenaPolicyBoundary(address(core));
        escrow = new EscrowEngine();
        target = new IdentityTarget();

        vm.prank(address(this));
        core.registerModule(
            bytes32("ESCROW_ENGINE"),
            address(escrow),
            "2.1.0"
        );

        vm.prank(operator);
        boundary.setAgentPolicy(
            agent,
            1 ether,
            10 ether,
            true
        );
    }

    function test_Attack_AttackerCannotReuseAgentEscrowProof() public {
        vm.prank(agent);

        uint256 escrowId = escrow.createEscrow(
            agent,
            address(target),
            1 ether
        );

        vm.prank(attacker);

        vm.expectRevert(
            AkmenaPolicyBoundary.UnauthorizedAgent.selector
        );

        boundary.executeAgentCall(
            operator,
            address(target),
            1 ether,
            bytes32("ESCROW_ENGINE"),
            escrowId,
            abi.encodeWithSelector(
                IdentityTarget.execute.selector
            )
        );
    }
}
