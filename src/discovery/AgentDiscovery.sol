// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../interfaces/IAgentDiscovery.sol";

/// @title Akmena Agent Discovery Engine
/// @notice Category-based indexing for agents.
contract AgentDiscovery is IAgentDiscovery {
    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    error AgentAlreadyIndexed();
    error InvalidCategory();

    // -------------------------------------------------------------------------
    // Storage
    // -------------------------------------------------------------------------

    mapping(string => bytes32[]) internal categoryAgents;

    mapping(bytes32 => bool) internal indexedAgents;

    // -------------------------------------------------------------------------
    // Actions
    // -------------------------------------------------------------------------

    function indexAgent(bytes32 agentId, string calldata category) external {
        if (indexedAgents[agentId]) {
            revert AgentAlreadyIndexed();
        }

        if (bytes(category).length == 0) {
            revert InvalidCategory();
        }

        categoryAgents[category].push(agentId);

        indexedAgents[agentId] = true;

        emit AgentIndexed(agentId, category);
    }

    // -------------------------------------------------------------------------
    // Views
    // -------------------------------------------------------------------------

    function getAgentsByCategory(string calldata category) external view returns (bytes32[] memory) {
        return categoryAgents[category];
    }

    function isIndexed(bytes32 agentId) external view returns (bool) {
        return indexedAgents[agentId];
    }
}
