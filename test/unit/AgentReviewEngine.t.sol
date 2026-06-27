// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../../src/reviews/AgentReviewEngine.sol";

contract AgentReviewEngineTest is Test {
    AgentReviewEngine engine;

    bytes32 constant AGENT_A = keccak256("agent-a");
    bytes32 constant AGENT_B = keccak256("agent-b");

    function setUp() public {
        engine = new AgentReviewEngine();
    }

    function testSubmitReview() public {
        engine.submitReview(AGENT_A, "Alice", "Excellent work");

        assertEq(engine.reviewCount(AGENT_A), 1);
    }

    function testCannotUseEmptyReviewer() public {
        vm.expectRevert();

        engine.submitReview(AGENT_A, "", "Good work");
    }

    function testCannotUseEmptyComment() public {
        vm.expectRevert();

        engine.submitReview(AGENT_A, "Alice", "");
    }

    function testReviewStoredCorrectly() public {
        engine.submitReview(AGENT_A, "Alice", "Excellent work");

        IAgentReviewEngine.Review[] memory reviews = engine.getReviews(AGENT_A);

        assertEq(reviews.length, 1);
        assertEq(reviews[0].agentId, AGENT_A);
        assertEq(reviews[0].reviewer, "Alice");
        assertEq(reviews[0].comment, "Excellent work");
    }

    function testTimestampSet() public {
        engine.submitReview(AGENT_A, "Alice", "Excellent work");

        IAgentReviewEngine.Review[] memory reviews = engine.getReviews(AGENT_A);

        assertGt(reviews[0].createdAt, 0);
    }

    function testMultipleReviewsAccumulate() public {
        engine.submitReview(AGENT_A, "Alice", "Excellent");

        engine.submitReview(AGENT_A, "Bob", "Very reliable");

        assertEq(engine.reviewCount(AGENT_A), 2);
    }

    function testDifferentAgentsHaveSeparateReviews() public {
        engine.submitReview(AGENT_A, "Alice", "Excellent");

        engine.submitReview(AGENT_B, "Bob", "Reliable");

        assertEq(engine.reviewCount(AGENT_A), 1);
        assertEq(engine.reviewCount(AGENT_B), 1);
    }

    function testUnknownAgentReturnsEmptyReviews() public view {
        assertEq(engine.reviewCount(AGENT_A), 0);
    }
}
