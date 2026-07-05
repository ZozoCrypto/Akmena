// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AgentRegistry} from "../../src/registry/AgentRegistry.sol";
import {IAgentRegistry} from "../../src/registry/interfaces/IAgentRegistry.sol";

contract RegistryTest is Test {
    AgentRegistry public registry;
    address public owner = address(0x1);
    address public agent = address(0x2);

    function setUp() public {
        registry = new AgentRegistry();
    }

    function test_Registry_Lifecycle() public {
        // 1. Register
        vm.prank(owner);
        registry.registerAgent(agent, "ipfs://metadata-uri");
        assertTrue(registry.isAgentActive(agent));

        // 2. Pause
        vm.prank(owner);
        registry.pauseAgent(agent);
        assertFalse(registry.isAgentActive(agent));

        // 3. Revoke (Kill Switch)
        vm.prank(owner);
        registry.revokeAgent(agent);
        
        // 4. Verify Revocation
        IAgentRegistry.AgentProfile memory profile = registry.getAgent(agent);
        assertEq(uint(profile.status), uint(IAgentRegistry.Status.REVOKED));
    }

    function test_UnauthorizedRevocation_Fails() public {
        vm.prank(owner);
        registry.registerAgent(agent, "ipfs://metadata-uri");

        // Attempt to revoke by a non-owner (e.g., a hacker)
        vm.prank(address(0x3));
        vm.expectRevert(); // Expect RegistryErrors.UnauthorizedOwner
        registry.revokeAgent(agent);
    }
}