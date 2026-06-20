// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../../src/registry/AgentRegistry.sol";

contract AgentRegistryInvariantTest is Test {
    AgentRegistry registry;

    bytes32 internal constant AGENT_ID = keccak256("agent-invariant");

    function setUp() public {
        registry = new AgentRegistry();

        registry.register(AGENT_ID, "ipfs://agent");
    }

    function invariant_AgentExists() public view {
        assertTrue(registry.exists(AGENT_ID));
    }

    function invariant_OwnerMappingIsConsistent() public view {
        assertEq(registry.agentOf(address(this)), AGENT_ID);
    }

    function invariant_TotalAgentsNeverZero() public view {
        assertGe(registry.totalAgents(), 1);
    }
}
