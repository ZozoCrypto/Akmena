// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaCore} from "../../../src/core/AkmenaCore.sol";
import {AkmenaPolicyBoundary} from "../../../src/authorization/AkmenaPolicyBoundary.sol";

contract ProofContextTarget {

    uint256 public executionCount;
    uint256 public lastValue;

    function privilegedAction(
        uint256 value
    )
        external
    {
        executionCount += 1;
        lastValue = value;
    }
}

contract ProofContextModule {

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

contract Attack_ProofContextSubstitutionTest is Test {

    AkmenaCore internal core;
    AkmenaPolicyBoundary internal boundary;

    ProofContextModule internal proofModule;
    ProofContextTarget internal target;

    address internal operator =
        address(0x1111);

    address internal agent =
        address(0x2222);

    bytes32 internal constant PROOF_MODULE_KEY =
        keccak256("P717_PROOF_CONTEXT");

    uint256 internal constant AUTHORIZED_PROOF_ID =
        1001;

    uint256 internal constant SUBSTITUTE_PROOF_ID =
        2002;

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
            new ProofContextModule();

        target =
            new ProofContextTarget();

        core.registerModule(
            PROOF_MODULE_KEY,
            address(proofModule),
            "1.0.0"
        );

        proofModule.setProof(
            AUTHORIZED_PROOF_ID
        );

        proofModule.setProof(
            SUBSTITUTE_PROOF_ID
        );

        vm.prank(operator);

        boundary.setAgentPolicy(
            agent,
            1 ether,
            10 ether,
            true
        );
    }

    function test_Attack_ProofIdCanBeSubstituted()
        public
    {
        bytes memory payload =
            abi.encodeWithSelector(
                ProofContextTarget.privilegedAction.selector,
                1 ether
            );

        /*
         * ==================================================
         * ORIGINAL PROOF CONTEXT
         * ==================================================
         *
         * The first execution establishes the intended
         * execution context using AUTHORIZED_PROOF_ID.
         */

        vm.prank(agent);

        boundary.executeAgentCall(
            operator,
            address(target),
            1 ether,
            PROOF_MODULE_KEY,
            AUTHORIZED_PROOF_ID,
            payload
        );

        assertEq(
            target.executionCount(),
            1,
            "authorized proof execution failed"
        );

        /*
         * ==================================================
         * PROOF-ID SUBSTITUTION
         * ==================================================
         *
         * Keep:
         *
         *     operator
         *     agent
         *     target
         *     selector
         *     calldata
         *     amount
         *     proof module
         *
         * Change ONLY:
         *
         *     proof ID
         */

        vm.prank(agent);

        boundary.executeAgentCall(
            operator,
            address(target),
            1 ether,
            PROOF_MODULE_KEY,
            SUBSTITUTE_PROOF_ID,
            payload
        );

        /*
         * Diagnostic objective:
         *
         * If this succeeds, proof IDs are accepted as
         * independent runtime authorization inputs rather
         * than being cryptographically bound to the original
         * execution intent.
         */

        assertEq(
            target.executionCount(),
            2,
            "proof-id substitution was blocked"
        );

        assertEq(
            target.lastValue(),
            1 ether,
            "substituted proof execution failed"
        );
    }

    function test_Attack_ProofModuleCanBeSubstituted()
        public
    {
        /*
         * Deploy a SECOND verifier with an independently
         * valid proof namespace.
         */
        ProofContextModule secondProofModule =
            new ProofContextModule();

        bytes32 secondModuleKey =
            keccak256("P717_SECOND_PROOF_CONTEXT");

        core.registerModule(
            secondModuleKey,
            address(secondProofModule),
            "1.0.0"
        );

        secondProofModule.setProof(
            SUBSTITUTE_PROOF_ID
        );

        bytes memory payload =
            abi.encodeWithSelector(
                ProofContextTarget.privilegedAction.selector,
                1 ether
            );

        /*
         * Original proof module works.
         */
        vm.prank(agent);

        boundary.executeAgentCall(
            operator,
            address(target),
            1 ether,
            PROOF_MODULE_KEY,
            AUTHORIZED_PROOF_ID,
            payload
        );

        assertEq(
            target.executionCount(),
            1,
            "original proof execution failed"
        );

        /*
         * Same execution intent, DIFFERENT proof module.
         */
        vm.prank(agent);

        boundary.executeAgentCall(
            operator,
            address(target),
            1 ether,
            secondModuleKey,
            SUBSTITUTE_PROOF_ID,
            payload
        );

        /*
         * Diagnostic objective:
         *
         * If this succeeds, the execution boundary permits
         * an entirely different proof authority to authorize
         * the same execution intent.
         */
        assertEq(
            target.executionCount(),
            2,
            "proof-module substitution was blocked"
        );
    }
}
