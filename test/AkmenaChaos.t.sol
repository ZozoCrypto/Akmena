// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {EscrowEngine} from "../src/economics/EscrowEngine.sol";
import {IEscrowEngine} from "../src/economics/IEscrowEngine.sol";
import {AgentRegistry} from "../src/registry/AgentRegistry.sol";
import {IAgentRegistry} from "../src/interfaces/IAgentRegistry.sol";

contract AkmenaChaosTest is Test {
    EscrowEngine internal escrowEngine;
    AgentRegistry internal agentRegistry;

    function setUp() public {
        escrowEngine = new EscrowEngine();
        agentRegistry = new AgentRegistry();
    }

    function testFuzz_AgentRegistrationIntegrity(bytes32 agentId, string memory metadata) public {
        bytes memory metaBytes = bytes(metadata);
        vm.assume(metaBytes.length > 0 && metaBytes.length < 256);

        agentRegistry.register(agentId, metadata);
        AgentRegistry.Agent memory agent = agentRegistry.getAgent(agentId);
        
        assertEq(agent.owner, address(this));
        assertEq(agent.metadataURI, metadata);
    }

    function testFuzz_CannotDoubleRelease(address buyer, address seller, uint256 amount) public {
        vm.assume(buyer != address(0) && seller != address(0));
        vm.assume(amount > 0 && amount < type(uint128).max);

        uint256 escrowId = escrowEngine.createEscrow(buyer, seller, amount);

        vm.prank(buyer);
        escrowEngine.releaseEscrow(escrowId);

        vm.prank(buyer);
        vm.expectRevert();
        escrowEngine.releaseEscrow(escrowId);
    }

    function testFuzz_CannotRefundUnlessSeller(address buyer, address seller, uint256 amount, address unauthorized) public {
        vm.assume(buyer != address(0) && seller != address(0) && unauthorized != address(0));
        vm.assume(unauthorized != seller);
        vm.assume(amount > 0 && amount < type(uint128).max);

        uint256 escrowId = escrowEngine.createEscrow(buyer, seller, amount);

        vm.prank(unauthorized);
        vm.expectRevert();
        escrowEngine.refundEscrow(escrowId);
    }

    function testFuzz_CannotReleaseUnlessBuyer(address buyer, address seller, uint256 amount, address unauthorized) public {
        vm.assume(buyer != address(0) && seller != address(0) && unauthorized != address(0));
        vm.assume(unauthorized != buyer);
        vm.assume(amount > 0 && amount < type(uint128).max);

        uint256 escrowId = escrowEngine.createEscrow(buyer, seller, amount);

        vm.prank(unauthorized);
        vm.expectRevert();
        escrowEngine.releaseEscrow(escrowId);
    }

    function testFuzz_CannotUpdateMetadataUnlessOwner(bytes32 agentId, address unauthorized) public {
        vm.assume(unauthorized != address(this) && unauthorized != address(0));

        agentRegistry.register(agentId, "initial.meta");

        vm.prank(unauthorized);
        vm.expectRevert();
        agentRegistry.updateMetadata(agentId, "hacked.meta");
    }
}
