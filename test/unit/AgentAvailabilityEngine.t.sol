// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";

import "../../src/availability/AgentAvailabilityEngine.sol";
import "../../src/interfaces/IAgentAvailabilityEngine.sol";

contract AgentAvailabilityEngineTest is Test {
    AgentAvailabilityEngine engine;

    bytes32 internal constant AGENT_ID = keccak256("agent-1");

    function setUp() public {
        engine = new AgentAvailabilityEngine();
    }

    function testSetAvailability() public {
        engine.setAvailability(AGENT_ID, IAgentAvailabilityEngine.Availability.Available);

        assertTrue(engine.isAvailable(AGENT_ID));
    }

    function testStatusPersists() public {
        engine.setAvailability(AGENT_ID, IAgentAvailabilityEngine.Availability.Busy);

        IAgentAvailabilityEngine.AgentAvailability memory record = engine.getAvailability(AGENT_ID);

        assertEq(uint256(record.status), uint256(IAgentAvailabilityEngine.Availability.Busy));
    }

    function testTimestampUpdates() public {
        engine.setAvailability(AGENT_ID, IAgentAvailabilityEngine.Availability.Available);

        IAgentAvailabilityEngine.AgentAvailability memory record = engine.getAvailability(AGENT_ID);

        assertGt(record.updatedAt, 0);
    }

    function testAvailableReturnsTrue() public {
        engine.setAvailability(AGENT_ID, IAgentAvailabilityEngine.Availability.Available);

        assertTrue(engine.isAvailable(AGENT_ID));
    }

    function testBusyReturnsFalse() public {
        engine.setAvailability(AGENT_ID, IAgentAvailabilityEngine.Availability.Busy);

        assertFalse(engine.isAvailable(AGENT_ID));
    }

    function testOfflineReturnsFalse() public {
        engine.setAvailability(AGENT_ID, IAgentAvailabilityEngine.Availability.Offline);

        assertFalse(engine.isAvailable(AGENT_ID));
    }

    function testUnknownAgentReturnsDefaultStruct() public view {
        IAgentAvailabilityEngine.AgentAvailability memory record = engine.getAvailability(AGENT_ID);

        assertEq(record.agentId, bytes32(0));
        assertEq(uint256(record.status), 0);
        assertEq(record.updatedAt, 0);
    }

    function testAvailabilityCanChange() public {
        engine.setAvailability(AGENT_ID, IAgentAvailabilityEngine.Availability.Available);

        engine.setAvailability(AGENT_ID, IAgentAvailabilityEngine.Availability.Busy);

        IAgentAvailabilityEngine.AgentAvailability memory record = engine.getAvailability(AGENT_ID);

        assertEq(uint256(record.status), uint256(IAgentAvailabilityEngine.Availability.Busy));
    }
}
