// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../../src/rewards/AgentRewardEngine.sol";

contract AgentRewardEngineTest is Test {
    AgentRewardEngine engine;

    bytes32 constant AGENT_A = keccak256("agent-a");
    bytes32 constant AGENT_B = keccak256("agent-b");

    function setUp() public {
        engine = new AgentRewardEngine();
    }

    function testGrantReward() public {
        engine.grantReward(AGENT_A, 100);

        assertEq(engine.totalRewards(AGENT_A), 100);
    }

    function testCannotGrantZeroReward() public {
        vm.expectRevert();

        engine.grantReward(AGENT_A, 0);
    }

    function testRewardsAccumulate() public {
        engine.grantReward(AGENT_A, 100);
        engine.grantReward(AGENT_A, 250);

        assertEq(engine.totalRewards(AGENT_A), 350);
    }

    function testRewardEventsAccumulate() public {
        engine.grantReward(AGENT_A, 100);
        engine.grantReward(AGENT_A, 250);

        assertEq(engine.rewardEvents(AGENT_A), 2);
    }

    function testDifferentAgentsHaveSeparateRewards() public {
        engine.grantReward(AGENT_A, 100);
        engine.grantReward(AGENT_B, 500);

        assertEq(engine.totalRewards(AGENT_A), 100);
        assertEq(engine.totalRewards(AGENT_B), 500);
    }

    function testGetRewardsReturnsCorrectData() public {
        engine.grantReward(AGENT_A, 100);

        IAgentRewardEngine.Reward memory reward = engine.getRewards(AGENT_A);

        assertEq(reward.agentId, AGENT_A);
        assertEq(reward.totalRewards, 100);
        assertEq(reward.rewardEvents, 1);
    }

    function testTimestampSet() public {
        engine.grantReward(AGENT_A, 100);

        IAgentRewardEngine.Reward memory reward = engine.getRewards(AGENT_A);

        assertGt(reward.lastRewardAt, 0);
    }

    function testUnknownAgentReturnsZeroTotals() public view {
        assertEq(engine.totalRewards(AGENT_A), 0);
        assertEq(engine.rewardEvents(AGENT_A), 0);
    }
}
