// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../../src/analytics/AgentAnalyticsEngine.sol";

contract AgentAnalyticsEngineTest is Test {
    AgentAnalyticsEngine engine;

    bytes32 constant AGENT_A = keccak256("agent-a");
    bytes32 constant AGENT_B = keccak256("agent-b");

    function setUp() public {
        engine = new AgentAnalyticsEngine();
    }

    function testUpdateAnalytics() public {
        engine.updateAnalytics(AGENT_A, 10, 1000, 95, 5);

        assertTrue(engine.hasAnalytics(AGENT_A));
    }

    function testAnalyticsStoredCorrectly() public {
        engine.updateAnalytics(AGENT_A, 10, 1000, 95, 5);

        IAgentAnalyticsEngine.Analytics memory data = engine.getAnalytics(AGENT_A);

        assertEq(data.agentId, AGENT_A);
        assertEq(data.completedTasks, 10);
        assertEq(data.totalEarned, 1000);
        assertEq(data.reputationScore, 95);
        assertEq(data.averageRating, 5);
    }

    function testAnalyticsCanBeUpdated() public {
        engine.updateAnalytics(AGENT_A, 10, 1000, 95, 5);

        engine.updateAnalytics(AGENT_A, 20, 2500, 98, 5);

        IAgentAnalyticsEngine.Analytics memory data = engine.getAnalytics(AGENT_A);

        assertEq(data.completedTasks, 20);
        assertEq(data.totalEarned, 2500);
        assertEq(data.reputationScore, 98);
    }

    function testDifferentAgentsHaveSeparateAnalytics() public {
        engine.updateAnalytics(AGENT_A, 10, 1000, 95, 5);

        engine.updateAnalytics(AGENT_B, 20, 5000, 99, 5);

        IAgentAnalyticsEngine.Analytics memory a = engine.getAnalytics(AGENT_A);

        IAgentAnalyticsEngine.Analytics memory b = engine.getAnalytics(AGENT_B);

        assertEq(a.totalEarned, 1000);
        assertEq(b.totalEarned, 5000);
    }

    function testHasAnalyticsReturnsTrue() public {
        engine.updateAnalytics(AGENT_A, 1, 100, 50, 4);

        assertTrue(engine.hasAnalytics(AGENT_A));
    }

    function testUnknownAgentReturnsFalse() public view {
        assertFalse(engine.hasAnalytics(AGENT_A));
    }

    function testTimestampSet() public {
        engine.updateAnalytics(AGENT_A, 10, 1000, 95, 5);

        IAgentAnalyticsEngine.Analytics memory data = engine.getAnalytics(AGENT_A);

        assertGt(data.updatedAt, 0);
    }

    function testUnknownAgentReturnsDefaultStruct() public view {
        IAgentAnalyticsEngine.Analytics memory data = engine.getAnalytics(AGENT_A);

        assertEq(data.totalEarned, 0);
        assertEq(data.completedTasks, 0);
    }
}
