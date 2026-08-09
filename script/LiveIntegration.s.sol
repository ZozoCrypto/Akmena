// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import "../src/registry/AgentRegistry.sol";
import "../src/economics/EscrowEngine.sol";

contract LiveIntegration is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);

        // Bind to our live verified Base Sepolia contracts
        AgentRegistry registry = AgentRegistry(0x940b6260Df7eBD78CB6484791F4B4f2Ccf9109D2);
        EscrowEngine escrow = EscrowEngine(0x7A3C240a3FfB054d1C588355C928Ed9118A18c63);

        console.log("Starting Live Integration on Base Sepolia as:", deployerAddress);

        // -----------------------------------------
        // 1. Register a Live Agent Identity
        // -----------------------------------------
        bytes32 agentId = keccak256(abi.encodePacked("AkmenaAgentMasterpiece", block.timestamp));
        registry.register(agentId, "ipfs://QmAkmenaMasterpieceV1");
        console.log("1. Success! Agent Registered with ID:");
        console.logBytes32(agentId);

        // -----------------------------------------
        // 2. Create a Live Escrow (buyer, seller, amount) -> returns escrowId
        // -----------------------------------------
        uint256 amount = 100; // Protocol unit amount
        uint256 escrowId = escrow.createEscrow(deployerAddress, deployerAddress, amount);
        console.log("2. Success! Escrow Created with ID:", escrowId);

        // -----------------------------------------
        // 3. Release the Escrow (escrowId, caller)
        // -----------------------------------------
        escrow.releaseEscrow(escrowId);
        console.log("3. Success! Escrow Released.");

        vm.stopBroadcast();
    }
}
