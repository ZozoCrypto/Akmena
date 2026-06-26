// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../../src/staking/AgentStakingEngine.sol";

contract AgentStakingEngineTest is Test {
    AgentStakingEngine engine;

    bytes32 constant AGENT_A = keccak256("agent-a");
    bytes32 constant AGENT_B = keccak256("agent-b");

    function setUp() public {
        engine = new AgentStakingEngine();
    }

    function testStake() public {
        engine.stake(AGENT_A, 100);

        assertEq(engine.stakedBalance(AGENT_A), 100);
    }

    function testCannotStakeZero() public {
        vm.expectRevert();

        engine.stake(AGENT_A, 0);
    }

    function testStakeAccumulates() public {
        engine.stake(AGENT_A, 100);
        engine.stake(AGENT_A, 250);

        assertEq(engine.stakedBalance(AGENT_A), 350);
    }

    function testUnstake() public {
        engine.stake(AGENT_A, 500);

        engine.unstake(AGENT_A, 200);

        assertEq(engine.stakedBalance(AGENT_A), 300);
    }

    function testCannotUnstakeTooMuch() public {
        engine.stake(AGENT_A, 100);

        vm.expectRevert();

        engine.unstake(AGENT_A, 200);
    }

    function testDifferentAgentsHaveSeparateStakes() public {
        engine.stake(AGENT_A, 100);
        engine.stake(AGENT_B, 500);

        assertEq(engine.stakedBalance(AGENT_A), 100);
        assertEq(engine.stakedBalance(AGENT_B), 500);
    }

    function testTimestampSetOnFirstStake() public {
        engine.stake(AGENT_A, 100);

        IAgentStakingEngine.Stake memory stakeInfo = engine.getStake(AGENT_A);

        assertGt(stakeInfo.stakedAt, 0);
    }

    function testUnknownAgentReturnsZeroBalance() public view {
        assertEq(engine.stakedBalance(AGENT_A), 0);
    }

    function testGetStakeReturnsCorrectData() public {
        engine.stake(AGENT_A, 400);

        IAgentStakingEngine.Stake memory stakeInfo = engine.getStake(AGENT_A);

        assertEq(stakeInfo.agentId, AGENT_A);
        assertEq(stakeInfo.amount, 400);
    }
}
