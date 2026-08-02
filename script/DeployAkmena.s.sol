// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import "../src/core/AkmenaCore.sol";
import "../src/economics/EscrowEngine.sol";
import "../src/registry/AgentRegistry.sol";

contract DeployAkmena is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy Core Protocol Registry
        AkmenaCore core = new AkmenaCore();
        console.log("AkmenaCore deployed at:", address(core));

        // 2. Deploy Escrow Engine
        EscrowEngine escrowEngine = new EscrowEngine();
        console.log("EscrowEngine deployed at:", address(escrowEngine));

        // 3. Deploy Agent Registry
        AgentRegistry agentRegistry = new AgentRegistry();
        console.log("AgentRegistry deployed at:", address(agentRegistry));

        // 4. Register modules to Core (using keccak256 module keys)
        bytes32 ESCROW_KEY = keccak256("akmena.module.escrow");
        bytes32 REGISTRY_KEY = keccak256("akmena.module.registry");

        core.registerModule(ESCROW_KEY, address(escrowEngine), "v2.0.0");
        core.registerModule(REGISTRY_KEY, address(agentRegistry), "v2.0.0");

        console.log("Modules registered successfully on Base Sepolia!");

        vm.stopBroadcast();
    }
}
