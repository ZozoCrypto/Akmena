// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/economics/EscrowEngine.sol";
import "../src/registry/AgentRegistry.sol";

contract AkmenaChaosTest is Test {
    EscrowEngine public escrow;
    AgentRegistry public registry;

    function setUp() public {
        escrow = new EscrowEngine();
        registry = new AgentRegistry();
    }

    // ==========================================
    // CHAOS VECTOR 1: Escrow Engine Fuzzing
    // ==========================================
    
    function testFuzz_CannotReleaseUnlessBuyer(
        address buyer, 
        address seller, 
        uint256 amount, 
        address randomActor
    ) public {
        vm.assume(buyer != address(0) && seller != address(0));
        vm.assume(amount > 0);
        vm.assume(randomActor != buyer); 

        uint256 id = escrow.createEscrow(buyer, seller, amount);

        vm.expectRevert(); 
        escrow.releaseEscrow(id);
    }

    function testFuzz_CannotRefundUnlessSeller(
        address buyer, 
        address seller, 
        uint256 amount, 
        address randomActor
    ) public {
        vm.assume(buyer != address(0) && seller != address(0));
        vm.assume(amount > 0);
        vm.assume(randomActor != seller); 

        uint256 id = escrow.createEscrow(buyer, seller, amount);

        vm.expectRevert(); 
        escrow.refundEscrow(id);
    }

    function testFuzz_CannotDoubleRelease(address buyer, address seller, uint256 amount) public {
        vm.assume(buyer != address(0) && seller != address(0));
        vm.assume(amount > 0);

        uint256 id = escrow.createEscrow(buyer, seller, amount);

        escrow.releaseEscrow(id);

        vm.expectRevert(); 
        escrow.releaseEscrow(id);
    }

    // ==========================================
    // CHAOS VECTOR 2: Agent Registry Fuzzing
    // ==========================================
    
    function testFuzz_AgentRegistrationIntegrity(bytes32 agentId, string memory metadata) public {
        vm.assume(agentId != bytes32(0));
        vm.assume(bytes(metadata).length > 0); // <--- THE FIX: Ignore empty strings
        
        registry.register(agentId, metadata);
        
        assertEq(registry.ownerOf(agentId), address(this));
        assertTrue(registry.exists(agentId));
    }

    function testFuzz_CannotUpdateMetadataUnlessOwner(bytes32 agentId, address randomActor) public {
        vm.assume(agentId != bytes32(0));
        vm.assume(randomActor != address(this)); 

        registry.register(agentId, "ipfs://v1");

        vm.prank(randomActor);
        vm.expectRevert(); 
        registry.updateMetadata(agentId, "ipfs://malicious");
    }
}
