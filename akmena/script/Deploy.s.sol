// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {AkmenaToken} from "../src/token/AkmenaToken.sol";
import {AgentRegistry} from "../src/registry/AgentRegistry.sol";
import {AkmenaEscrow} from "../src/escrow/AkmenaEscrow.sol";

contract DeployAkmenaCore is Script {
    function run() external {
        // Load the private key securely from the .env file
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);

        console.log("Booting Akmena V1-Core M2M Infrastructure...");
        console.log("Deployer Address:", deployerAddress);

        // Begin transaction broadcast to the network
        vm.startBroadcast(deployerPrivateKey);

        // Phase 1: Deploy the Financial Kernel
        AkmenaToken token = new AkmenaToken(deployerAddress);
        console.log("-> AkmenaToken deployed at:", address(token));

        // Phase 2: Deploy the Identity Layer
        AgentRegistry registry = new AgentRegistry();
        console.log("-> AgentRegistry deployed at:", address(registry));

        // Phase 3: Deploy the Escrow Engine (Linked to Token)
        AkmenaEscrow escrow = new AkmenaEscrow(address(token));
        console.log("-> AkmenaEscrow deployed at:", address(escrow));

        vm.stopBroadcast();

        console.log("=== Base Network Deployment Complete ===");
    }
}