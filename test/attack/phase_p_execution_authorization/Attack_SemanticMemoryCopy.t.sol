// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

contract SemanticMemoryCopyHarness {

    struct Intent {
        bytes32 contextHash;
        bytes32 purposeHash;
        uint256 nonce;
    }

    function makeIntent()
        external
        pure
        returns (Intent memory)
    {
        return Intent({
            contextHash: keccak256("original-context"),
            purposeHash: keccak256("original-purpose"),
            nonce: 1
        });
    }

    function mutateCopy()
        external
        pure
        returns (
            bytes32 originalContext,
            bytes32 mutatedContext,
            bytes32 originalPurpose,
            bytes32 mutatedPurpose
        )
    {
        Intent memory original = Intent({
            contextHash: keccak256("original-context"),
            purposeHash: keccak256("original-purpose"),
            nonce: 1
        });

        Intent memory mutated = original;

        mutated.contextHash =
            bytes32(uint256(0x2222));

        mutated.purposeHash =
            bytes32(uint256(0x1111));

        originalContext = original.contextHash;
        mutatedContext = mutated.contextHash;
        originalPurpose = original.purposeHash;
        mutatedPurpose = mutated.purposeHash;
    }
}

contract Attack_SemanticMemoryCopyTest is Test {

    SemanticMemoryCopyHarness internal harness;

    function setUp() public {
        harness = new SemanticMemoryCopyHarness();
    }

    function test_MemoryStructCopyIsIndependent()
        public
    {
        (
            bytes32 originalContext,
            bytes32 mutatedContext,
            bytes32 originalPurpose,
            bytes32 mutatedPurpose
        ) = harness.mutateCopy();

        assertTrue(
            originalContext != mutatedContext,
            "context mutation leaked or did not apply"
        );

        assertTrue(
            originalPurpose != mutatedPurpose,
            "purpose mutation leaked or did not apply"
        );

        assertEq(
            mutatedContext,
            bytes32(uint256(0x2222))
        );

        assertEq(
            mutatedPurpose,
            bytes32(uint256(0x1111))
        );
    }
}
