// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../../src/ratings/AgentRatingEngine.sol";
import "../../src/interfaces/IAgentRatingEngine.sol";

contract AgentRatingEngineTest is Test {
    AgentRatingEngine engine;

    bytes32 internal constant AGENT_ID = keccak256("agent-a");

    address internal constant REVIEWER_A = address(0x1001);

    address internal constant REVIEWER_B = address(0x1002);

    function setUp() public {
        engine = new AgentRatingEngine();
    }

    function testSubmitRating() public {
        vm.prank(REVIEWER_A);

        engine.submitRating(AGENT_ID, 5);

        assertEq(engine.getRatingCount(AGENT_ID), 1);
    }

    function testAverageRating() public {
        vm.prank(REVIEWER_A);
        engine.submitRating(AGENT_ID, 5);

        vm.prank(REVIEWER_B);
        engine.submitRating(AGENT_ID, 3);

        assertEq(engine.getAverageRating(AGENT_ID), 4);
    }

    function testRatingCountAccumulates() public {
        vm.prank(REVIEWER_A);
        engine.submitRating(AGENT_ID, 5);

        vm.prank(REVIEWER_B);
        engine.submitRating(AGENT_ID, 4);

        assertEq(engine.getRatingCount(AGENT_ID), 2);
    }

    function testHasRatedReturnsTrue() public {
        vm.prank(REVIEWER_A);

        engine.submitRating(AGENT_ID, 5);

        assertTrue(engine.hasRated(AGENT_ID, REVIEWER_A));
    }

    function testCannotRateTwice() public {
        vm.startPrank(REVIEWER_A);

        engine.submitRating(AGENT_ID, 5);

        vm.expectRevert(AgentRatingEngine.AlreadyRated.selector);

        engine.submitRating(AGENT_ID, 4);

        vm.stopPrank();
    }

    function testCannotUseZeroScore() public {
        vm.prank(REVIEWER_A);

        vm.expectRevert(AgentRatingEngine.InvalidScore.selector);

        engine.submitRating(AGENT_ID, 0);
    }

    function testCannotUseScoreAboveFive() public {
        vm.prank(REVIEWER_A);

        vm.expectRevert(AgentRatingEngine.InvalidScore.selector);

        engine.submitRating(AGENT_ID, 6);
    }

    function testUnknownAgentAverageReturnsZero() public view {
        assertEq(engine.getAverageRating(AGENT_ID), 0);
    }

    function testUnknownAgentCountReturnsZero() public view {
        assertEq(engine.getRatingCount(AGENT_ID), 0);
    }
}
