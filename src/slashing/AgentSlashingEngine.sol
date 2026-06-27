// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../interfaces/IAgentSlashingEngine.sol";

contract AgentSlashingEngine is IAgentSlashingEngine {
    error ZeroAmount();

    mapping(bytes32 => SlashRecord) internal slashRecords;

    function slash(bytes32 agentId, uint256 amount) external {
        if (amount == 0) {
            revert ZeroAmount();
        }

        SlashRecord storage record = slashRecords[agentId];

        record.agentId = agentId;
        record.totalSlashed += amount;
        record.slashCount += 1;
        record.lastSlashedAt = block.timestamp;

        emit AgentSlashed(agentId, amount);
    }

    function getSlashRecord(bytes32 agentId) external view returns (SlashRecord memory) {
        return slashRecords[agentId];
    }

    function totalSlashed(bytes32 agentId) external view returns (uint256) {
        return slashRecords[agentId].totalSlashed;
    }

    function slashCount(bytes32 agentId) external view returns (uint256) {
        return slashRecords[agentId].slashCount;
    }
}
