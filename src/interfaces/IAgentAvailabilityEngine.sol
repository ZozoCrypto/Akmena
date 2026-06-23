// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IAgentAvailabilityEngine {
    enum Availability {
        Offline,
        Available,
        Busy
    }

    struct AgentAvailability {
        bytes32 agentId;
        Availability status;
        uint256 updatedAt;
    }

    event AvailabilityUpdated(bytes32 indexed agentId, Availability status);

    function setAvailability(bytes32 agentId, Availability status) external;

    function getAvailability(bytes32 agentId) external view returns (AgentAvailability memory);

    function isAvailable(bytes32 agentId) external view returns (bool);
}
