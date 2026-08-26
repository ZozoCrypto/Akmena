// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaCore} from "../../../src/core/AkmenaCore.sol";
import {AkmenaPolicyBoundary} from "../../../src/authorization/AkmenaPolicyBoundary.sol";

contract FullIntentTargetA {

    uint256 public executionCount;
    uint256 public receivedAmount;

    function authorizedAction(
        uint256 amount
    )
        external
    {
        executionCount += 1;
        receivedAmount = amount;
    }
}

contract FullIntentTargetB {

    uint256 public executionCount;
    uint256 public receivedAmount;

    function attackerAction(
        uint256 amount
    )
        external
    {
        executionCount += 1;
        receivedAmount = amount;
    }
}

contract FullIntentProofModule {

    mapping(uint256 => bool) public validProofs;

    function setProof(
        uint256 proofId
    )
        external
    {
        validProofs[proofId] = true;
    }

    function verifyTransientProof(
        uint256 proofId,
        address,
        uint256
    )
        external
        view
        returns (bool)
    {
        return validProofs[proofId];
    }
}

contract Attack_FullExecutionIntentSubstitutionTest is Test {

    AkmenaCore internal core;
    AkmenaPolicyBoundary internal boundary;

    FullIntentProofModule internal proofModule;
    FullIntentTargetA internal authorizedTarget;
    FullIntentTargetB internal attackerTarget;

    address internal operator =
        address(0x1111);

    address internal agent =
        address(0x2222);

    bytes32 internal constant PROOF_MODULE_KEY =
        keccak256("P716_FULL_INTENT_PROOF");

    uint256 internal constant PROOF_ID =
        777;

    function setUp()
        public
    {
        core =
            new AkmenaCore();

        boundary =
            new AkmenaPolicyBoundary(
                address(core)
            );

        proofModule =
            new FullIntentProofModule();

        authorizedTarget =
            new FullIntentTargetA();

        attackerTarget =
            new FullIntentTargetB();

        core.registerModule(
            PROOF_MODULE_KEY,
            address(proofModule),
            "1.0.0"
        );

        proofModule.setProof(
            PROOF_ID
        );

        vm.prank(operator);

        boundary.setAgentPolicy(
            agent,
            1 ether,
            10 ether,
            true
        );
    }

    function test_Attack_FullExecutionIntentCanBeSubstituted()
        public
    {
        /*
         * ==================================================
         * INTENDED AUTHORIZED EXECUTION
         * ==================================================
         *
         * Conceptual authorization:
         *
         * target:
         *     authorizedTarget
         *
         * selector:
         *     authorizedAction(uint256)
         *
         * calldata:
         *     authorizedAction(1 ether)
         *
         * proof:
         *     PROOF_MODULE_KEY / PROOF_ID
         */

        bytes memory authorizedPayload =
            abi.encodeWithSelector(
                FullIntentTargetA.authorizedAction.selector,
                1 ether
            );

        vm.prank(agent);

        boundary.executeAgentCall(
            operator,
            address(authorizedTarget),
            1 ether,
            PROOF_MODULE_KEY,
            PROOF_ID,
            authorizedPayload
        );

        assertEq(
            authorizedTarget.executionCount(),
            1,
            "authorized execution did not occur"
        );

        assertEq(
            authorizedTarget.receivedAmount(),
            1 ether,
            "authorized calldata did not execute"
        );

        /*
         * ==================================================
         * COMPLETE EXECUTION-INTENT SUBSTITUTION
         * ==================================================
         *
         * KEEP:
         *
         *     operator
         *     agent
         *     amount
         *     proof module
         *     proof ID
         *
         * CHANGE:
         *
         *     target
         *     selector
         *     calldata
         *
         * This represents a completely different execution
         * intent under the same proof context.
         */

        bytes memory attackerPayload =
            abi.encodeWithSelector(
                FullIntentTargetB.attackerAction.selector,
                1 ether
            );

        vm.prank(agent);

        boundary.executeAgentCall(
            operator,
            address(attackerTarget),
            1 ether,
            PROOF_MODULE_KEY,
            PROOF_ID,
            attackerPayload
        );

        /*
         * Diagnostic objective:
         *
         * If this passes, the real PolicyBoundary allows
         * a valid proof context to authorize an entirely
         * different execution target, selector and calldata.
         */

        assertEq(
            attackerTarget.executionCount(),
            1,
            "full execution-intent substitution was blocked"
        );

        assertEq(
            attackerTarget.receivedAmount(),
            1 ether,
            "substituted execution calldata was blocked"
        );
    }
}
