// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../interfaces/IAgentSkillEngine.sol";

contract AgentSkillEngine is IAgentSkillEngine {
    error EmptySkill();

    mapping(bytes32 => Skill[]) internal skills;
    mapping(bytes32 => mapping(bytes32 => bool)) internal skillExists;

    function addSkill(bytes32 agentId, string calldata skill) external {
        if (bytes(skill).length == 0) {
            revert EmptySkill();
        }

        bytes32 skillHash = keccak256(bytes(skill));

        skills[agentId].push(Skill({agentId: agentId, name: skill, addedAt: block.timestamp}));

        skillExists[agentId][skillHash] = true;

        emit SkillAdded(agentId, skill);
    }

    function getSkills(bytes32 agentId) external view returns (Skill[] memory) {
        return skills[agentId];
    }

    function hasSkill(bytes32 agentId, bytes32 skillHash) external view returns (bool) {
        return skillExists[agentId][skillHash];
    }
}
