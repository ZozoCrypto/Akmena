// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../../src/slashing/AgentSlashingEngine.sol";

contract AgentSlashingEngineTest is Test {
    AgentSlashingEngine engine;

    bytes32 constant AGENT_A = keccak256("agent-a");
    bytes32 constant AGENT_B = keccak256("agent-b");

    function setUp() public {
        engine = new AgentSlashingEngine();
    }

    function testSlash() public {
        engine.slash(AGENT_A, 100);

        assertEq(engine.totalSlashed(AGENT_A), 100);
    }

    function testCannotSlashZero() public {
        vm.expectRevert();

        engine.slash(AGENT_A, 0);
    }

    function testMultipleSlashesAccumulate() public {
        engine.slash(AGENT_A, 100);
        engine.slash(AGENT_A, 250);

        assertEq(engine.totalSlashed(AGENT_A), 350);
    }

    function testSlashCountAccumulates() public {
        engine.slash(AGENT_A, 50);
        engine.slash(AGENT_A, 75);
        engine.slash(AGENT_A, 25);

        assertEq(engine.slashCount(AGENT_A), 3);
    }

    function testDifferentAgentsHaveSeparateRecords() public {
        engine.slash(AGENT_A, 100);
        engine.slash(AGENT_B, 500);

        assertEq(engine.totalSlashed(AGENT_A), 100);
        assertEq(engine.totalSlashed(AGENT_B), 500);
    }

    function testTimestampSet() public {
        engine.slash(AGENT_A, 100);

        IAgentSlashingEngine.SlashRecord memory record = engine.getSlashRecord(AGENT_A);

        assertGt(record.lastSlashedAt, 0);
    }

    function testSlashRecordStoredCorrectly() public {
        engine.slash(AGENT_A, 400);

        IAgentSlashingEngine.SlashRecord memory record = engine.getSlashRecord(AGENT_A);

        assertEq(record.agentId, AGENT_A);
        assertEq(record.totalSlashed, 400);
        assertEq(record.slashCount, 1);
    }

    function testUnknownAgentReturnsZeroTotals() public view {
        assertEq(engine.totalSlashed(AGENT_A), 0);
        assertEq(engine.slashCount(AGENT_A), 0);
    }
}
