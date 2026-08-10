// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {AkmenaCore} from "../src/core/AkmenaCore.sol";
import {EscrowEngine} from "../src/economics/EscrowEngine.sol";
import {AgreementEngine} from "../src/autonomous/AgreementEngine.sol";
import {AgentRegistry} from "../src/registry/AgentRegistry.sol";

contract LiveIntegrationScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying Akmena V2 Masterpiece from:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy Core Router (Nuclear-Hardened Registry)
        AkmenaCore core = new AkmenaCore();
        console.log("AkmenaCore deployed at:", address(core));

        // 2. Deploy Protocol Engines
        EscrowEngine escrowEngine = new EscrowEngine();
        console.log("EscrowEngine deployed at:", address(escrowEngine));

        AgreementEngine agreementEngine = new AgreementEngine();
        console.log("AgreementEngine deployed at:", address(agreementEngine));

        AgentRegistry agentRegistry = new AgentRegistry();
        console.log("AgentRegistry deployed at:", address(agentRegistry));

        // 3. Register Modules into Core Router (ERC-8109 Introspection Compliant)
        core.registerModule(bytes32("ESCROW_ENGINE"), address(escrowEngine), "2.0.0");
        core.registerModule(bytes32("AGREEMENT_ENGINE"), address(agreementEngine), "2.0.0");
        core.registerModule(bytes32("AGENT_REGISTRY"), address(agentRegistry), "2.0.0");

        vm.stopBroadcast();
        console.log("Akmena V2 Live Integration Handshake Complete.");
    }
}
