// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IAgentRegistry {
    enum Status { UNREGISTERED, ACTIVE, PAUSED, REVOKED }

    struct AgentProfile {
        address owner;
        Status status;
        uint256 registeredAt;
        string metadataURI; // IPFS link to the Agent's AI model details, version, and SLA
    }

    event AgentRegistered(address indexed agent, address indexed owner);
    event AgentStatusUpdated(address indexed agent, Status newStatus);
    event MetadataUpdated(address indexed agent, string newURI);

    function registerAgent(address agent, string calldata metadataURI) external;
    function pauseAgent(address agent) external;
    function revokeAgent(address agent) external;
    function getAgent(address agent) external view returns (AgentProfile memory);
    function isAgentActive(address agent) external view returns (bool);
}