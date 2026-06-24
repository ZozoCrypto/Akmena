// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IAgentSkillEngine {
    struct Skill {
        bytes32 agentId;
        string name;
        uint256 addedAt;
    }

    event SkillAdded(bytes32 indexed agentId, string skill);

    function addSkill(bytes32 agentId, string calldata skill) external;

    function getSkills(bytes32 agentId) external view returns (Skill[] memory);

    function hasSkill(bytes32 agentId, bytes32 skillHash) external view returns (bool);
}
