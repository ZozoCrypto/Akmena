// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaCore} from "../../../src/core/AkmenaCore.sol";
import {AkmenaPolicyBoundary} from "../../../src/authorization/AkmenaPolicyBoundary.sol";

contract ProofReplayCalldataTarget {

    uint256 public executionCount;
    address public lastRecipient;
    uint256 public lastAmount;

    function transferValue(
        address recipient,
        uint256 amount
    )
        external
    {
        executionCount += 1;
        lastRecipient = recipient;
        lastAmount = amount;
    }
}

contract CalldataReplayProofModule {

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

contract Attack_ProofReplayCalldataMutationTest is Test {

    AkmenaCore internal core;
    AkmenaPolicyBoundary internal boundary;

    CalldataReplayProofModule internal proofModule;
    ProofReplayCalldataTarget internal target;

    address internal operator =
        address(0x1111);

    address internal agent =
        address(0x2222);

    address internal originalRecipient =
        address(0xAAAA);

    address internal substitutedRecipient =
        address(0xBBBB);

    bytes32 internal constant PROOF_MODULE_KEY =
        keccak256("P720_CALLDATA_REPLAY");

    uint256 internal constant PROOF_ID =
        9201;

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
            new CalldataReplayProofModule();

        target =
            new ProofReplayCalldataTarget();

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

    function test_Attack_SameProofCanAuthorizeDifferentCalldata()
        public
    {
        /*
         * ==================================================
         * ORIGINAL EXECUTION
         * ==================================================
         */

        bytes memory originalPayload =
            abi.encodeWithSelector(
                ProofReplayCalldataTarget.transferValue.selector,
                originalRecipient,
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
            target.executionCount(),
            1,
            "original calldata execution failed"
        );

        assertEq(
            target.lastRecipient(),
            originalRecipient,
            "original recipient mismatch"
        );

        assertEq(
            target.lastAmount(),
            1 ether,
            "original amount mismatch"
        );

        /*
         * ==================================================
         * SAME PROOF / DIFFERENT CALLDATA
         * ==================================================
         *
         * Keep:
         *
         *     operator
         *     agent
         *     target
         *     selector
         *     policy amount
         *     proof module
         *     proof ID
         *
         * Change ONLY the encoded recipient.
         */

        bytes memory substitutedPayload =
            abi.encodeWithSelector(
                ProofReplayCalldataTarget.transferValue.selector,
                substitutedRecipient,
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
         * If this succeeds, the same proof can authorize
         * materially different calldata against the same
         * target and selector.
         */

        assertEq(
            target.executionCount(),
            2,
            "same-proof calldata substitution was blocked"
        );

        assertEq(
            target.lastRecipient(),
            substitutedRecipient,
            "substituted calldata recipient was blocked"
        );

        assertEq(
            target.lastAmount(),
            1 ether,
            "substituted calldata amount mismatch"
        );
    }
}
