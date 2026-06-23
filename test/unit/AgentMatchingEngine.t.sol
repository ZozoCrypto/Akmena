// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../../src/matching/AgentMatchingEngine.sol";
import "../../src/interfaces/IAgentMatchingEngine.sol";

contract AgentMatchingEngineTest is Test {
    AgentMatchingEngine engine;

    bytes32 internal constant AGENT_A = keccak256("agent-a");
    bytes32 internal constant AGENT_B = keccak256("agent-b");

    function setUp() public {
        engine = new AgentMatchingEngine();
    }

    function testSetScore() public {
        engine.setScore(AGENT_A, 100);

        assertEq(engine.getScore(AGENT_A), 100);
    }

    function testMatchStoredCorrectly() public {
        engine.setScore(AGENT_A, 500);

        IAgentMatchingEngine.Match memory m = engine.getMatch(AGENT_A);

        assertEq(m.agentId, AGENT_A);
        assertEq(m.score, 500);
    }

    function testExistsReturnsTrue() public {
        engine.setScore(AGENT_A, 100);

        assertTrue(engine.exists(AGENT_A));
    }

    function testUnknownAgentReturnsFalse() public view {
        assertFalse(engine.exists(AGENT_A));
    }

    function testCannotUseZeroScore() public {
        vm.expectRevert(AgentMatchingEngine.InvalidScore.selector);

        engine.setScore(AGENT_A, 0);
    }

    function testCannotScoreAgentTwice() public {
        engine.setScore(AGENT_A, 100);

        vm.expectRevert(AgentMatchingEngine.AgentAlreadyScored.selector);

        engine.setScore(AGENT_A, 200);
    }

    function testGetUnknownMatchReverts() public {
        vm.expectRevert(AgentMatchingEngine.MatchNotFound.selector);

        engine.getMatch(AGENT_A);
    }

    function testGetUnknownScoreReverts() public {
        vm.expectRevert(AgentMatchingEngine.MatchNotFound.selector);

        engine.getScore(AGENT_A);
    }

    function testDifferentAgentsCanExist() public {
        engine.setScore(AGENT_A, 900);
        engine.setScore(AGENT_B, 700);

        assertEq(engine.getScore(AGENT_A), 900);
        assertEq(engine.getScore(AGENT_B), 700);
    }
}
