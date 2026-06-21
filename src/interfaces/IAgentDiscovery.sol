// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title Akmena Agent Discovery Interface
/// @notice Simple category-based agent discovery.
interface IAgentDiscovery {
    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    event AgentIndexed(bytes32 indexed agentId, string category);

    // -------------------------------------------------------------------------
    // Actions
    // -------------------------------------------------------------------------

    function indexAgent(bytes32 agentId, string calldata category) external;

    // -------------------------------------------------------------------------
    // Views
    // -------------------------------------------------------------------------

    function getAgentsByCategory(string calldata category) external view returns (bytes32[] memory);

    function isIndexed(bytes32 agentId) external view returns (bool);
}
