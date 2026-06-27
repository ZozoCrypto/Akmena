// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IAgentSlashingEngine {
    struct SlashRecord {
        bytes32 agentId;
        uint256 totalSlashed;
        uint256 slashCount;
        uint256 lastSlashedAt;
    }

    event AgentSlashed(bytes32 indexed agentId, uint256 amount);

    function slash(bytes32 agentId, uint256 amount) external;

    function getSlashRecord(bytes32 agentId) external view returns (SlashRecord memory);

    function totalSlashed(bytes32 agentId) external view returns (uint256);

    function slashCount(bytes32 agentId) external view returns (uint256);
}
