// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {AkmenaCore} from "../src/core/AkmenaCore.sol";
import {EscrowEngine} from "../src/economics/EscrowEngine.sol";
import {AkmenaPolicyBoundary} from "../src/authorization/AkmenaPolicyBoundary.sol";

contract DeployCoreArchitecture is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy the Central Router
        AkmenaCore core = new AkmenaCore();
        console.log("AkmenaCore deployed at:", address(core));

        // 2. Deploy the Escrow Engine
        EscrowEngine escrow = new EscrowEngine();
        console.log("EscrowEngine deployed at:", address(escrow));

        // 3. Register Escrow to Core
        core.registerModule(bytes32("ESCROW_ENGINE"), address(escrow), "2.1.0");
        console.log("EscrowEngine registered to Core");

        // 4. Deploy the AI Policy Boundary
        AkmenaPolicyBoundary boundary = new AkmenaPolicyBoundary(address(core));
        console.log("AkmenaPolicyBoundary deployed at:", address(boundary));

        vm.stopBroadcast();
    }
}
