// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaCore} from "../../../src/core/AkmenaCore.sol";
import {AkmenaPolicyBoundary} from "../../../src/authorization/AkmenaPolicyBoundary.sol";

contract ProofReplayTarget {
    uint256 public executionCount;
    address public lastCaller;
    uint256 public lastAmount;

    function execute(uint256 amount) external {
        executionCount += 1;
        lastCaller = msg.sender;
        lastAmount = amount;
    }
}

contract ReplayProofModule {
    mapping(uint256 => bool) public validProofs;

    function setProof(uint256 proofId) external {
        validProofs[proofId] = true;
    }

    function verifyTransientProof(uint256 proofId, address, uint256) external view returns (bool) {
        return validProofs[proofId];
    }
}

contract Attack_ProofReplayAcrossIntentsTest is Test {
    AkmenaCore internal core;
    AkmenaPolicyBoundary internal boundary;

    ReplayProofModule internal proofModule;
    ProofReplayTarget internal target;

    address internal operator = address(0x1111);

    address internal agent = address(0x2222);

    bytes32 internal constant PROOF_MODULE_KEY = keccak256("P718_REPLAY_PROOF");

    uint256 internal constant PROOF_ID = 9001;

    function setUp() public {
        core = new AkmenaCore();

        boundary = new AkmenaPolicyBoundary(address(core));

        proofModule = new ReplayProofModule();

        target = new ProofReplayTarget();

        core.registerModule(PROOF_MODULE_KEY, address(proofModule), "1.0.0");

        proofModule.setProof(PROOF_ID);

        vm.prank(operator);

        boundary.setAgentPolicy(agent, 10 ether, 20 ether, true);
    }

    function test_Attack_SameProofCanAuthorizeMultipleExecutions() public {
        /*
         * ==================================================
         * FIRST EXECUTION
         * ==================================================
         *
         * The proof is valid and the first execution succeeds.
         */

        bytes memory firstPayload = abi.encodeWithSelector(ProofReplayTarget.execute.selector, 1 ether);

        vm.prank(agent);

        boundary.executeAgentCall(operator, address(target), 1 ether, PROOF_MODULE_KEY, PROOF_ID, firstPayload);

        assertEq(target.executionCount(), 1, "first proof-backed execution failed");

        /*
         * ==================================================
         * SECOND EXECUTION
         * ==================================================
         *
         * EXACT SAME:
         *
         *     operator
         *     agent
         *     proof module
         *     proof ID
         *
         * DIFFERENT:
         *
         *     calldata amount
         *
         * The proof itself is never regenerated.
         */

        bytes memory secondPayload = abi.encodeWithSelector(ProofReplayTarget.execute.selector, 9 ether);

        vm.prank(agent);

        boundary.executeAgentCall(operator, address(target), 9 ether, PROOF_MODULE_KEY, PROOF_ID, secondPayload);

        /*
         * Diagnostic objective:
         *
         * If this passes, the same proof can authorize
         * multiple materially different executions.
         */

        assertEq(target.executionCount(), 2, "proof replay across intents was blocked");

        assertEq(target.lastAmount(), 9 ether, "second execution did not occur");
    }

    function test_Attack_SameProofCanAuthorizeDifferentTarget() public {
        ProofReplayTarget secondTarget = new ProofReplayTarget();

        bytes memory payload = abi.encodeWithSelector(ProofReplayTarget.execute.selector, 1 ether);

        /*
         * First target.
         */

        vm.prank(agent);

        boundary.executeAgentCall(operator, address(target), 1 ether, PROOF_MODULE_KEY, PROOF_ID, payload);

        /*
         * Same proof, different target.
         */

        vm.prank(agent);

        boundary.executeAgentCall(operator, address(secondTarget), 1 ether, PROOF_MODULE_KEY, PROOF_ID, payload);

        /*
         * Diagnostic objective:
         *
         * A proof that authorized execution against target A
         * is reusable against target B.
         */

        assertEq(target.executionCount(), 1, "first target did not execute");

        assertEq(secondTarget.executionCount(), 1, "same proof could not execute second target");
    }
}
