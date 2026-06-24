// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../../src/skills/AgentSkillEngine.sol";

contract AgentSkillEngineTest is Test {
    AgentSkillEngine engine;

    bytes32 constant AGENT_A = keccak256("agent-a");
    bytes32 constant AGENT_B = keccak256("agent-b");

    function setUp() public {
        engine = new AgentSkillEngine();
    }

    function testAddSkill() public {
        engine.addSkill(AGENT_A, "Solidity");

        assertEq(engine.getSkills(AGENT_A).length, 1);
    }

    function testSkillStoredCorrectly() public {
        engine.addSkill(AGENT_A, "Solidity");

        IAgentSkillEngine.Skill[] memory skills = engine.getSkills(AGENT_A);

        assertEq(skills[0].agentId, AGENT_A);
        assertEq(skills[0].name, "Solidity");
    }

    function testHasSkillReturnsTrue() public {
        engine.addSkill(AGENT_A, "Solidity");

        bytes32 hash = keccak256(bytes("Solidity"));

        assertTrue(engine.hasSkill(AGENT_A, hash));
    }

    function testUnknownSkillReturnsFalse() public view {
        bytes32 hash = keccak256(bytes("Rust"));

        assertFalse(engine.hasSkill(AGENT_A, hash));
    }

    function testMultipleSkillsAccumulate() public {
        engine.addSkill(AGENT_A, "Solidity");
        engine.addSkill(AGENT_A, "Foundry");
        engine.addSkill(AGENT_A, "Base");

        assertEq(engine.getSkills(AGENT_A).length, 3);
    }

    function testDifferentAgentsHaveSeparateSkills() public {
        engine.addSkill(AGENT_A, "Solidity");
        engine.addSkill(AGENT_B, "Rust");

        assertEq(engine.getSkills(AGENT_A).length, 1);

        assertEq(engine.getSkills(AGENT_B).length, 1);
    }

    function testCannotAddEmptySkill() public {
        vm.expectRevert(AgentSkillEngine.EmptySkill.selector);

        engine.addSkill(AGENT_A, "");
    }

    function testTimestampSet() public {
        engine.addSkill(AGENT_A, "Solidity");

        IAgentSkillEngine.Skill[] memory skills = engine.getSkills(AGENT_A);

        assertEq(skills[0].addedAt, block.timestamp);
    }
}
