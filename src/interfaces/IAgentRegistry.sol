// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title Akmena Agent Registry Interface
/// @author Akmena
/// @notice Canonical interface for protocol agent registration.
/// @dev Every protocol component should depend on this interface
/// instead of the concrete AgentRegistry implementation.
interface IAgentRegistry {
    // -------------------------------------------------------------------------
    // Structs
    // -------------------------------------------------------------------------

    struct Agent {
        bytes32 id;
        address owner;
        uint64 createdAt;
        uint64 updatedAt;
        uint32 version;
        bool active;
        bool verified;
        string metadataURI;
    }

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    /// @notice Emitted when a new agent is registered.
    event AgentRegistered(bytes32 indexed id, address indexed owner, string metadataURI);

    /// @notice Emitted when an agent updates its metadata.
    event MetadataUpdated(bytes32 indexed id, string metadataURI, uint32 version);

    // -------------------------------------------------------------------------
    // Registry
    // -------------------------------------------------------------------------

    /// @notice Registers a new protocol agent.
    /// @param id Canonical agent identifier.
    /// @param metadataURI URI describing the agent.
    function register(bytes32 id, string calldata metadataURI) external;

    /// @notice Updates an existing agent's metadata.
    /// @param id Agent identifier.
    /// @param metadataURI New metadata URI.
    function updateMetadata(bytes32 id, string calldata metadataURI) external;

    // -------------------------------------------------------------------------
    // Views
    // -------------------------------------------------------------------------

    /// @notice Returns true if an agent exists.
    /// @param id Agent identifier.
    function exists(bytes32 id) external view returns (bool);

    /// @notice Returns total registered agents.
    function totalAgents() external view returns (uint256);

    /// @notice Returns the agent id owned by an address.
    /// @param owner Agent owner.
    function agentOf(address owner) external view returns (bytes32);

    /// @notice Returns the complete agent record.
    /// @param id Agent identifier.
    function getAgent(bytes32 id) external view returns (Agent memory);
}
