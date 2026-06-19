// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../../src/registry/AgentRegistry.sol";

contract AgentRegistryTest is Test {
    AgentRegistry registry;

    function setUp() public {
        registry = new AgentRegistry();
    }

    function testInitialAgentCountIsZero() public view {
        assertEq(registry.totalAgents(), 0);
    }

    function testRegisterAgent() public {
        bytes32 id = keccak256("agent-1");

        registry.register(id, "ipfs://akmena-agent");

        assertEq(registry.totalAgents(), 1);

        assertTrue(registry.exists(id));

        assertEq(registry.agentOf(address(this)), id);
    }
}
