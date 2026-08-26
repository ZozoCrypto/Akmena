// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaCore} from "../../../src/core/AkmenaCore.sol";
import {AkmenaPolicyBoundary} from "../../../src/authorization/AkmenaPolicyBoundary.sol";

contract ProofReplaySelectorTarget {

    uint256 public authorizedCount;
    uint256 public substitutedCount;
    uint256 public lastAmount;

    function authorizedAction(
        uint256 amount
    )
        external
    {
        authorizedCount += 1;
        lastAmount = amount;
    }

    function substitutedAction(
        uint256 amount
    )
        external
    {
        substitutedCount += 1;
        lastAmount = amount;
    }
}

contract SelectorReplayProofModule {

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

contract Attack_ProofReplaySelectorMutationTest is Test {

    AkmenaCore internal core;
    AkmenaPolicyBoundary internal boundary;

    SelectorReplayProofModule internal proofModule;
    ProofReplaySelectorTarget internal target;

    address internal operator =
        address(0x1111);

    address internal agent =
        address(0x2222);

    bytes32 internal constant PROOF_MODULE_KEY =
        keccak256("P719_SELECTOR_REPLAY");

    uint256 internal constant PROOF_ID =
        9191;

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
            new SelectorReplayProofModule();

        target =
            new ProofReplaySelectorTarget();

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

    function test_Attack_SameProofCanAuthorizeDifferentSelector()
        public
    {
        /*
         * ==================================================
         * ORIGINAL EXECUTION
         * ==================================================
         */

        bytes memory originalPayload =
            abi.encodeWithSelector(
                ProofReplaySelectorTarget.authorizedAction.selector,
                1 ether
            );

        vm.prank(agent);

        boundary.executeAgentCall(
            operator,
            address(target),
            1 ether,
            PROOF_MODULE_KEY,
            PROOF_ID,
            originalPayload
        );

        assertEq(
            target.authorizedCount(),
            1,
            "original action did not execute"
        );

        /*
         * ==================================================
         * SAME PROOF / DIFFERENT SELECTOR
         * ==================================================
         *
         * Keep absolutely everything else identical.
         */

        bytes memory substitutedPayload =
            abi.encodeWithSelector(
                ProofReplaySelectorTarget.substitutedAction.selector,
                1 ether
            );

        vm.prank(agent);

        boundary.executeAgentCall(
            operator,
            address(target),
            1 ether,
            PROOF_MODULE_KEY,
            PROOF_ID,
            substitutedPayload
        );

        /*
         * Diagnostic objective:
         *
         * If this succeeds, the SAME proof can authorize
         * a different selector on the SAME target for the
         * SAME economic amount.
         */

        assertEq(
            target.substitutedCount(),
            1,
            "same-proof selector substitution was blocked"
        );

        assertEq(
            target.lastAmount(),
            1 ether,
            "substituted action amount mismatch"
        );
    }
}
