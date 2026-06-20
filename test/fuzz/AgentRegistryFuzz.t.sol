// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../../src/registry/AgentRegistry.sol";

contract AgentRegistryFuzzTest is Test {
    AgentRegistry registry;

    function setUp() public {
        registry = new AgentRegistry();
    }

    function testFuzzRegisterAgent(bytes32 id, string memory metadataURI) public {
        vm.assume(id != bytes32(0));
        vm.assume(bytes(metadataURI).length > 0);

        registry.register(id, metadataURI);

        assertTrue(registry.exists(id));

        assertEq(registry.totalAgents(), 1);

        AgentRegistry.Agent memory agent = registry.getAgent(id);

        assertEq(agent.owner, address(this));

        assertEq(agent.metadataURI, metadataURI);
    }
}
