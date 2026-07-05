// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IAgentRegistry} from "./interfaces/IAgentRegistry.sol";
import {RegistryErrors} from "./lib/RegistryErrors.sol";

/// @title AgentRegistry
/// @author Akmena Protocol
/// @notice The source of truth for AI Agent identities on the Akmena network.
contract AgentRegistry is IAgentRegistry {
    mapping(address => AgentProfile) private _agents;

    // ═════════════════════════════════════════════════════════════════════
    // Core Registration
    // ═════════════════════════════════════════════════════════════════════

    /// @notice Registers a new AI Agent. The caller becomes the immutable Owner.
    /// @param agent The public address of the AI Agent (EOA or Smart Account).
    /// @param metadataURI IPFS link to the Agent's configuration/specs.
    function registerAgent(address agent, string calldata metadataURI) external override {
        if (agent == address(0)) revert RegistryErrors.ZeroAddress();
        if (_agents[agent].status != Status.UNREGISTERED) revert RegistryErrors.AgentAlreadyRegistered();

        _agents[agent] = AgentProfile({
            owner: msg.sender, // The human/DAO creating the agent
            status: Status.ACTIVE,
            registeredAt: block.timestamp,
            metadataURI: metadataURI
        });

        emit AgentRegistered(agent, msg.sender);
    }

    // ═════════════════════════════════════════════════════════════════════
    // Lifecycle Management
    // ═════════════════════════════════════════════════════════════════════

    modifier onlyOwner(address agent) {
        if (_agents[agent].status == Status.UNREGISTERED) revert RegistryErrors.AgentNotRegistered();
        if (_agents[agent].owner != msg.sender) revert RegistryErrors.UnauthorizedOwner();
        _;
    }

    /// @notice Temporarily pauses an agent (e.g., during maintenance or a minor bug).
    function pauseAgent(address agent) external override onlyOwner(agent) {
        if (_agents[agent].status == Status.REVOKED) revert RegistryErrors.AgentRevoked();
        
        _agents[agent].status = Status.PAUSED;
        emit AgentStatusUpdated(agent, Status.PAUSED);
    }

    /// @notice Unpauses an agent.
    function activateAgent(address agent) external onlyOwner(agent) {
        if (_agents[agent].status == Status.REVOKED) revert RegistryErrors.AgentRevoked();
        
        _agents[agent].status = Status.ACTIVE;
        emit AgentStatusUpdated(agent, Status.ACTIVE);
    }

    /// @notice The "Kill Switch". Permanently revokes the agent's network access.
    function revokeAgent(address agent) external override onlyOwner(agent) {
        _agents[agent].status = Status.REVOKED;
        emit AgentStatusUpdated(agent, Status.REVOKED);
    }

    /// @notice Updates the machine-readable details of the agent.
    function updateMetadata(address agent, string calldata newURI) external onlyOwner(agent) {
        if (_agents[agent].status == Status.REVOKED) revert RegistryErrors.AgentRevoked();
        
        _agents[agent].metadataURI = newURI;
        emit MetadataUpdated(agent, newURI);
    }

    // ═════════════════════════════════════════════════════════════════════
    // View Functions
    // ═════════════════════════════════════════════════════════════════════

    function getAgent(address agent) external view override returns (AgentProfile memory) {
        return _agents[agent];
    }

    function isAgentActive(address agent) external view override returns (bool) {
        return _agents[agent].status == Status.ACTIVE;
    }
}