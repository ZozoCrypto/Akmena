// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../../src/registry/AgentRegistry.sol";

contract AgentRegistryTest is Test {
    AgentRegistry registry;

    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);

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

    // -------------------------------------------------------------------------
    // Verification
    // -------------------------------------------------------------------------

    function testRegistryOwnerCanVerifyAgent() public {
        vm.prank(alice);
        registry.register(AGENT_ID, INITIAL_URI);

        registry.setVerification(AGENT_ID, true);

        assertTrue(registry.isVerified(AGENT_ID));
    }

    function testNonOwnerCannotVerifyAgent() public {
        vm.prank(alice);
        registry.register(AGENT_ID, INITIAL_URI);

        vm.prank(bob);

        vm.expectRevert(AgentRegistry.Unauthorized.selector);

        registry.setVerification(AGENT_ID, true);
    }

    function testVerificationStateUpdates() public {
        vm.prank(alice);
        registry.register(AGENT_ID, INITIAL_URI);

        registry.setVerification(AGENT_ID, true);

        assertTrue(registry.isVerified(AGENT_ID));

        registry.setVerification(AGENT_ID, false);

        assertFalse(registry.isVerified(AGENT_ID));
    }

    function testCannotVerifyUnknownAgent() public {
        vm.expectRevert(AgentRegistry.AgentNotFound.selector);

        registry.setVerification(keccak256("missing-agent"), true);
    }

    // -------------------------------------------------------------------------
    // ownerOf
    // -------------------------------------------------------------------------

    function testOwnerOfReturnsCorrectOwner() public {
        vm.prank(alice);
        registry.register(AGENT_ID, INITIAL_URI);

        assertEq(registry.ownerOf(AGENT_ID), alice);
    }

    function testOwnerOfUnknownAgentReverts() public {
        vm.expectRevert(AgentRegistry.AgentNotFound.selector);

        registry.ownerOf(keccak256("missing-agent"));
    }
}
