// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../../src/earnings/AgentEarningsEngine.sol";

contract AgentEarningsEngineTest is Test {
    AgentEarningsEngine engine;

    bytes32 constant AGENT_A = keccak256("agent-a");
    bytes32 constant AGENT_B = keccak256("agent-b");

    function setUp() public {
        engine = new AgentEarningsEngine();
    }

    function testRecordEarnings() public {
        engine.recordEarnings(AGENT_A, 100);

        assertEq(engine.totalEarned(AGENT_A), 100);
    }

    function testCannotRecordZeroAmount() public {
        vm.expectRevert();

        engine.recordEarnings(AGENT_A, 0);
    }

    function testTotalEarnedAccumulates() public {
        engine.recordEarnings(AGENT_A, 100);
        engine.recordEarnings(AGENT_A, 250);

        assertEq(engine.totalEarned(AGENT_A), 350);
    }

    function testTransactionCountAccumulates() public {
        engine.recordEarnings(AGENT_A, 100);
        engine.recordEarnings(AGENT_A, 250);

        assertEq(engine.transactionCount(AGENT_A), 2);
    }

    function testDifferentAgentsHaveSeparateEarnings() public {
        engine.recordEarnings(AGENT_A, 100);
        engine.recordEarnings(AGENT_B, 500);

        assertEq(engine.totalEarned(AGENT_A), 100);
        assertEq(engine.totalEarned(AGENT_B), 500);
    }

    function testGetEarningsReturnsCorrectData() public {
        engine.recordEarnings(AGENT_A, 100);

        IAgentEarningsEngine.Earnings memory earnings = engine.getEarnings(AGENT_A);

        assertEq(earnings.agentId, AGENT_A);
        assertEq(earnings.totalEarned, 100);
        assertEq(earnings.transactionCount, 1);
    }

    function testTimestampSet() public {
        engine.recordEarnings(AGENT_A, 100);

        IAgentEarningsEngine.Earnings memory earnings = engine.getEarnings(AGENT_A);

        assertGt(earnings.lastPaymentAt, 0);
    }

    function testUnknownAgentReturnsZeroTotals() public view {
        assertEq(engine.totalEarned(AGENT_A), 0);
        assertEq(engine.transactionCount(AGENT_A), 0);
    }
}
