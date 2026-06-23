// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../interfaces/IAgentAvailabilityEngine.sol";

contract AgentAvailabilityEngine is IAgentAvailabilityEngine {
    mapping(bytes32 => AgentAvailability) internal availability;

    function setAvailability(bytes32 agentId, Availability status) external {
        availability[agentId] = AgentAvailability({agentId: agentId, status: status, updatedAt: block.timestamp});

        emit AvailabilityUpdated(agentId, status);
    }

    function getAvailability(bytes32 agentId) external view returns (AgentAvailability memory) {
        return availability[agentId];
    }

    function isAvailable(bytes32 agentId) external view returns (bool) {
        return availability[agentId].status == Availability.Available;
    }
}
