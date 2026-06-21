// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../../src/discovery/AgentDiscovery.sol";

contract AgentDiscoveryTest is Test {
    AgentDiscovery discovery;

    bytes32 internal constant AGENT_A = keccak256("agent-a");
    bytes32 internal constant AGENT_B = keccak256("agent-b");

    string internal constant CATEGORY = "ai";
    string internal constant UNKNOWN_CATEGORY = "unknown";

    function setUp() public {
        discovery = new AgentDiscovery();
    }

    function testIndexAgent() public {
        discovery.indexAgent(AGENT_A, CATEGORY);

        assertTrue(discovery.isIndexed(AGENT_A));
    }

    function testCannotIndexTwice() public {
        discovery.indexAgent(AGENT_A, CATEGORY);

        vm.expectRevert(AgentDiscovery.AgentAlreadyIndexed.selector);

        discovery.indexAgent(AGENT_A, CATEGORY);
    }

    function testCannotIndexEmptyCategory() public {
        vm.expectRevert(AgentDiscovery.InvalidCategory.selector);

        discovery.indexAgent(AGENT_A, "");
    }

    function testGetAgentsByCategory() public {
        discovery.indexAgent(AGENT_A, CATEGORY);

        bytes32[] memory agents = discovery.getAgentsByCategory(CATEGORY);

        assertEq(agents.length, 1);
    }

    function testCategoryContainsIndexedAgent() public {
        discovery.indexAgent(AGENT_A, CATEGORY);

        bytes32[] memory agents = discovery.getAgentsByCategory(CATEGORY);

        assertEq(agents[0], AGENT_A);
    }

    function testMultipleAgentsSameCategory() public {
        discovery.indexAgent(AGENT_A, CATEGORY);
        discovery.indexAgent(AGENT_B, CATEGORY);

        bytes32[] memory agents = discovery.getAgentsByCategory(CATEGORY);

        assertEq(agents.length, 2);
        assertEq(agents[0], AGENT_A);
        assertEq(agents[1], AGENT_B);
    }

    function testUnknownCategoryReturnsEmptyArray() public view {
        bytes32[] memory agents = discovery.getAgentsByCategory(UNKNOWN_CATEGORY);

        assertEq(agents.length, 0);
    }

    function testIsIndexedReturnsTrue() public {
        discovery.indexAgent(AGENT_A, CATEGORY);

        assertTrue(discovery.isIndexed(AGENT_A));
    }
}
