// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../../src/registry/AgentRegistry.sol";

contract AgentRegistryTest is Test {
    AgentRegistry registry;

    bytes32 internal constant AGENT_ID = keccak256("agent-1");

    string internal constant INITIAL_URI = "ipfs://akmena-agent";

    string internal constant UPDATED_URI = "ipfs://updated-agent";

    function setUp() public {
        registry = new AgentRegistry();
    }

    function testInitialAgentCountIsZero() public view {
        assertEq(registry.totalAgents(), 0);
    }

    function testRegisterAgent() public {
        registry.register(AGENT_ID, INITIAL_URI);

        assertEq(registry.totalAgents(), 1);

        assertTrue(registry.exists(AGENT_ID));

        assertEq(registry.agentOf(address(this)), AGENT_ID);
    }

    function testUpdateMetadata() public {
        registry.register(AGENT_ID, INITIAL_URI);

        registry.updateMetadata(AGENT_ID, UPDATED_URI);

        AgentRegistry.Agent memory agent = registry.getAgent(AGENT_ID);

        assertEq(agent.metadataURI, UPDATED_URI);

        assertEq(agent.version, 2);
    }

    function testCannotUpdateUnknownAgent() public {
        vm.expectRevert(AgentRegistry.AgentNotFound.selector);

        registry.updateMetadata(AGENT_ID, UPDATED_URI);
    }

    function testCannotUpdateWithEmptyMetadata() public {
        registry.register(AGENT_ID, INITIAL_URI);

        vm.expectRevert(AgentRegistry.InvalidMetadata.selector);

        registry.updateMetadata(AGENT_ID, "");
    }
}
