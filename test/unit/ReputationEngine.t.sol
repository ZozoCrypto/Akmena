// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../../src/reputation/ReputationEngine.sol";
import "../../src/interfaces/IReputationEngine.sol";

contract ReputationEngineTest is Test {
    ReputationEngine engine;

    bytes32 internal constant AGENT_ID = keccak256("agent-a");

    function setUp() public {
        engine = new ReputationEngine();
    }

    function testRewardIncreasesScore() public {
        engine.reward(AGENT_ID, 100);

        IReputationEngine.Reputation memory reputation = engine.getReputation(AGENT_ID);

        assertEq(reputation.score, 100);
    }

    function testPenaltyDecreasesScore() public {
        engine.reward(AGENT_ID, 100);
        engine.penalize(AGENT_ID, 40);

        IReputationEngine.Reputation memory reputation = engine.getReputation(AGENT_ID);

        assertEq(reputation.score, 60);
    }

    function testPenaltyCannotUnderflow() public {
        engine.reward(AGENT_ID, 50);
        engine.penalize(AGENT_ID, 100);

        IReputationEngine.Reputation memory reputation = engine.getReputation(AGENT_ID);

        assertEq(reputation.score, 0);
    }

    function testCompletionCounterIncrements() public {
        engine.recordCompletion(AGENT_ID);

        IReputationEngine.Reputation memory reputation = engine.getReputation(AGENT_ID);

        assertEq(reputation.completedAgreements, 1);
    }

    function testMultipleCompletionsAccumulate() public {
        engine.recordCompletion(AGENT_ID);
        engine.recordCompletion(AGENT_ID);
        engine.recordCompletion(AGENT_ID);

        IReputationEngine.Reputation memory reputation = engine.getReputation(AGENT_ID);

        assertEq(reputation.completedAgreements, 3);
    }

    function testUnknownAgentStartsAtZero() public view {
        IReputationEngine.Reputation memory reputation = engine.getReputation(AGENT_ID);

        assertEq(reputation.score, 0);
        assertEq(reputation.completedAgreements, 0);
        assertEq(reputation.acceptedAgreements, 0);
        assertEq(reputation.rejectedAgreements, 0);
    }

    function testRewardThenPenaltyProducesExpectedScore() public {
        engine.reward(AGENT_ID, 100);
        engine.penalize(AGENT_ID, 25);

        IReputationEngine.Reputation memory reputation = engine.getReputation(AGENT_ID);

        assertEq(reputation.score, 75);
    }

    function testZeroPointRewardReverts() public {
        vm.expectRevert(ReputationEngine.InvalidPoints.selector);
        engine.reward(AGENT_ID, 0);
    }
}
