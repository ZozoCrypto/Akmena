// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {AkmenaCore} from "../src/core/AkmenaCore.sol";
import {EscrowEngine} from "../src/economics/EscrowEngine.sol";
import {SettlementEngine} from "../src/economics/SettlementEngine.sol";
import {TreasuryEngine} from "../src/economics/TreasuryEngine.sol";
import {PaymentsEngine} from "../src/economics/PaymentsEngine.sol";
import {AkmenaPolicyBoundary} from "../src/authorization/AkmenaPolicyBoundary.sol";
import {WorkflowEngine} from "../src/orchestration/WorkflowEngine.sol";
import {DelegationEngine} from "../src/authorization/DelegationEngine.sol";
import {AttestationEngine} from "../src/authorization/AttestationEngine.sol";
import {PrivacyEngine} from "../src/privacy/PrivacyEngine.sol";
import {StealthAddressRegistry} from "../src/privacy/StealthAddressRegistry.sol";

contract DeployAkmena is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        console.log("Deploying Akmena Nuclear-Hardened Protocol on Base...");

        AkmenaCore core = new AkmenaCore();
        EscrowEngine escrow = new EscrowEngine();
        SettlementEngine settlement = new SettlementEngine();
        TreasuryEngine treasury = new TreasuryEngine();
        PaymentsEngine payments = new PaymentsEngine();
        AkmenaPolicyBoundary policyBoundary = new AkmenaPolicyBoundary(address(core));
        WorkflowEngine workflow = new WorkflowEngine(address(core));
        DelegationEngine delegation = new DelegationEngine();
        AttestationEngine attestation = new AttestationEngine();
        
        // Native Protocol Privacy Execution 
        PrivacyEngine privacy = new PrivacyEngine();
        StealthAddressRegistry stealthRegistry = new StealthAddressRegistry();

        core.registerModule(bytes32("ESCROW_ENGINE"), address(escrow), "2.0.0");
        core.registerModule(bytes32("SETTLEMENT_ENGINE"), address(settlement), "2.0.0");
        core.registerModule(bytes32("TREASURY_ENGINE"), address(treasury), "2.0.0");
        core.registerModule(bytes32("PAYMENTS_ENGINE"), address(payments), "2.0.0");
        core.registerModule(bytes32("POLICY_BOUNDARY"), address(policyBoundary), "2.0.0");
        core.registerModule(bytes32("WORKFLOW_ENGINE"), address(workflow), "2.0.0");
        core.registerModule(bytes32("DELEGATION_ENGINE"), address(delegation), "2.0.0");
        core.registerModule(bytes32("ATTESTATION_ENGINE"), address(attestation), "2.0.0");
        
        // Locking Privacy Constraints into the Router
        core.registerModule(bytes32("PRIVACY_ENGINE"), address(privacy), "1.0.0");
        core.registerModule(bytes32("STEALTH_REGISTRY"), address(stealthRegistry), "1.0.0");

        console.log("All modules registered and locked successfully.");

        vm.stopBroadcast();
    }
}
