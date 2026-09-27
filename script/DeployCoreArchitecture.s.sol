// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {AkmenaCore} from "../src/core/AkmenaCore.sol";
import {EscrowEngine} from "../src/economics/EscrowEngine.sol";
import {AkmenaToken} from "../src/token/core/AkmenaToken.sol";
import {AkmenaPolicyBoundary} from "../src/authorization/AkmenaPolicyBoundary.sol";
import {AkmenaExecutionAuthorization} from "../src/authorization/AkmenaExecutionAuthorization.sol";

contract DeployCoreArchitecture is Script {
    function run() external {
        require(block.chainid == 84532, "DeployCoreArchitecture: Base Sepolia only");

        vm.startBroadcast();

        // 1. Deploy the Central Router
        AkmenaCore core = new AkmenaCore();
        console.log("AkmenaCore deployed at:", address(core));

        // 2. Deploy the canonical AKM monetary asset
        AkmenaToken token = new AkmenaToken(msg.sender);
        console.log("AkmenaToken deployed at:", address(token));

        // 3. Deploy the Escrow Engine with canonical AKM custody
        EscrowEngine escrow = new EscrowEngine(address(token));
        console.log("EscrowEngine deployed at:", address(escrow));

        // 4. Register Escrow to Core
        // forge-lint: disable-next-line(unsafe-typecast)
        core.registerModule(
"ESCROW_ENGINE", address(escrow), "2.1.0");
        console.log("EscrowEngine registered to Core");

        // 5. Deploy the AI Policy Boundary
        AkmenaPolicyBoundary boundary = new AkmenaPolicyBoundary(address(core));
        console.log("AkmenaPolicyBoundary deployed at:", address(boundary));

        // 6. Discover the execution authorization contract created
        //    by the Policy Boundary constructor.
        AkmenaExecutionAuthorization executionAuthorization = boundary.executionAuthorization();

        console.log("AkmenaExecutionAuthorization deployed at:", address(executionAuthorization));

        // 7. Emit deployment identity.
        console.log("Deployer:", msg.sender);
        console.log("Chain ID:", block.chainid);
        console.log("Deployment block:", block.number);

        vm.stopBroadcast();
    }
}
