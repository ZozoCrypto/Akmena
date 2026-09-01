// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {AgentRegistry} from "../../../src/registry/AgentRegistry.sol";

contract AttackCanonicalRegistryVerificationAuthorityTest is Test {
    AgentRegistry internal registry;

    address internal registryOwner;
    address internal agentOwner = address(0xA11CE);
    address internal attacker = address(0xBEEF);

    bytes32 internal constant AGENT_ID =
        keccak256("canonical-agent");

    string internal constant METADATA =
        "ipfs://akmena-agent";

    function setUp() public {
        registry = new AgentRegistry();

        registryOwner = address(this);

        vm.prank(agentOwner);
        registry.register(
            AGENT_ID,
            METADATA
        );
    }

    function test_RegistryOwnerCanVerifyAgent()
        public
    {
        registry.setVerification(
            AGENT_ID,
            true
        );

        assertTrue(
            registry.isVerified(AGENT_ID)
        );
    }

    function test_RegistryOwnerCanRevokeVerification()
        public
    {
        registry.setVerification(
            AGENT_ID,
            true
        );

        registry.setVerification(
            AGENT_ID,
            false
        );

        assertFalse(
            registry.isVerified(AGENT_ID)
        );
    }

    function test_AttackerCannotForgeVerification()
        public
    {
        vm.prank(attacker);

        vm.expectRevert(
            AgentRegistry.Unauthorized.selector
        );

        registry.setVerification(
            AGENT_ID,
            true
        );

        assertFalse(
            registry.isVerified(AGENT_ID)
        );
    }

    function test_AgentOwnerCannotSelfVerify()
        public
    {
        vm.prank(agentOwner);

        vm.expectRevert(
            AgentRegistry.Unauthorized.selector
        );

        registry.setVerification(
            AGENT_ID,
            true
        );

        assertFalse(
            registry.isVerified(AGENT_ID)
        );
    }

    function test_UnknownAgentCannotBeVerified()
        public
    {
        vm.expectRevert(
            AgentRegistry.AgentNotFound.selector
        );

        registry.setVerification(
            keccak256("missing-agent"),
            true
        );
    }
}
