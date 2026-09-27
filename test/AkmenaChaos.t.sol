// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {EscrowEngine} from "../src/economics/EscrowEngine.sol";
import {AkmenaToken} from "../src/token/core/AkmenaToken.sol";
import {IEscrowEngine} from "../src/economics/IEscrowEngine.sol";
import {AgentRegistry} from "../src/registry/AgentRegistry.sol";
import {IAgentRegistry} from "../src/interfaces/IAgentRegistry.sol";

contract AkmenaChaosTest is Test {
    EscrowEngine internal escrowEngine;
    AkmenaToken internal token;
    AgentRegistry internal agentRegistry;

    function setUp() public {
        token = new AkmenaToken(address(this));
        escrowEngine = new EscrowEngine(address(token));
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

    function _createFundedEscrow(address buyer, address seller, uint256 amount) internal returns (uint256 escrowId) {
        vm.assume(buyer != address(0));
        vm.assume(seller != address(0));
        vm.assume(amount > 0);

        // Fund the real buyer because EscrowEngine now requires
        // msg.sender == buyer and pulls AKM from the buyer.
        require(token.transfer(buyer, amount));

        vm.prank(buyer);
        token.approve(address(escrowEngine), amount);

        vm.prank(buyer);
        escrowId = escrowEngine.createEscrow(buyer, seller, amount);
    }

    function testFuzz_CannotDoubleRelease(address buyer, address seller, uint256 amount) public {
        amount = bound(amount, 1, 1000 ether);

        uint256 escrowId = _createFundedEscrow(buyer, seller, amount);

        vm.prank(buyer);
        escrowEngine.releaseEscrow(escrowId);

        vm.prank(buyer);
        vm.expectRevert();
        escrowEngine.releaseEscrow(escrowId);
    }

    function testFuzz_CannotRefundUnlessSeller(address buyer, address seller, uint256 amount, address unauthorized)
        public
    {
        amount = bound(amount, 1, 1000 ether);

        vm.assume(unauthorized != address(0));
        vm.assume(unauthorized != seller);

        uint256 escrowId = _createFundedEscrow(buyer, seller, amount);

        vm.prank(unauthorized);
        vm.expectRevert();
        escrowEngine.refundEscrow(escrowId);
    }

    function testFuzz_CannotReleaseUnlessBuyer(address buyer, address seller, uint256 amount, address unauthorized)
        public
    {
        amount = bound(amount, 1, 1000 ether);

        vm.assume(unauthorized != address(0));
        vm.assume(unauthorized != buyer);

        uint256 escrowId = _createFundedEscrow(buyer, seller, amount);

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
