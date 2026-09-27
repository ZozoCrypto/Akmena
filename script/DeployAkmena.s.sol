// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";

import {AkmenaCore} from "../src/core/AkmenaCore.sol";
import {AkmenaToken} from "../src/token/core/AkmenaToken.sol";

import {EscrowEngine} from "../src/economics/EscrowEngine.sol";
import {EconomicCommitmentEngine} from "../src/economics/EconomicCommitmentEngine.sol";
import {PaymentsEngine} from "../src/economics/PaymentsEngine.sol";
import {AgreementEngine} from "../src/autonomous/AgreementEngine.sol";
import {MarketplaceEngine} from "../src/autonomous/MarketplaceEngine.sol";

import {AkmenaPolicyBoundary} from "../src/authorization/AkmenaPolicyBoundary.sol";
import {CapabilityEngine} from "../src/authorization/CapabilityEngine.sol";
import {AuthorizationResolver} from "../src/authorization/AuthorizationResolver.sol";
import {DelegationEngine} from "../src/authorization/DelegationEngine.sol";
import {AttestationEngine} from "../src/authorization/AttestationEngine.sol";

import {WorkflowEngine} from "../src/orchestration/WorkflowEngine.sol";
import {WorkflowMemoryAdapter} from "../src/orchestration/adapters/WorkflowMemoryAdapter.sol";
import {WorkflowReputationAdapter} from "../src/orchestration/adapters/WorkflowReputationAdapter.sol";
import {WorkflowEconomicSettlementAdapter} from "../src/orchestration/adapters/WorkflowEconomicSettlementAdapter.sol";

import {MemoryEngine} from "../src/memory/MemoryEngine.sol";
import {ReputationEngine} from "../src/reputation/ReputationEngine.sol";

import {Registry} from "../src/registry/Registry.sol";
import {Identity} from "../src/identity/Identity.sol";
import {IdentityFactory} from "../src/identity/IdentityFactory.sol";

import {PrivacyEngine} from "../src/privacy/PrivacyEngine.sol";
import {StealthAddressRegistry} from "../src/privacy/StealthAddressRegistry.sol";

import {ModuleKeys} from "../src/libraries/ModuleKeys.sol";

contract DeployAkmena is Script {
    struct Deployment {
        AkmenaCore core;
        AkmenaToken token;
        EscrowEngine escrow;
        AgreementEngine agreement;
        MarketplaceEngine marketplace;
        EconomicCommitmentEngine economic;
        PaymentsEngine payments;
        MemoryEngine memoryEngine;
        ReputationEngine reputation;
        AkmenaPolicyBoundary policyBoundary;
        Registry registry;
        Identity identityImplementation;
        IdentityFactory identityFactory;
        CapabilityEngine capabilityEngine;
        DelegationEngine delegation;
        AuthorizationResolver authorizationResolver;
        WorkflowEngine workflow;
        WorkflowEconomicSettlementAdapter settlementAdapter;
        WorkflowMemoryAdapter memoryAdapter;
        WorkflowReputationAdapter reputationAdapter;
        AttestationEngine attestation;
        PrivacyEngine privacy;
        StealthAddressRegistry stealthRegistry;
    }

    function run() external {
        require(block.chainid == 84532, "DeployAkmena: Base Sepolia only");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        console.log("Deploying Akmena canonical Sprint 10 architecture...");

        Deployment memory d;

        // ---------------------------------------------------------------------
        // Core + monetary primitives
        // ---------------------------------------------------------------------

        d.core = new AkmenaCore();
        d.token = new AkmenaToken(deployer);
        d.escrow = new EscrowEngine(address(d.token));
        d.agreement = new AgreementEngine();
        d.marketplace = new MarketplaceEngine();
        d.economic = new EconomicCommitmentEngine(address(d.agreement), address(d.escrow));
        d.payments = new PaymentsEngine();

        // ---------------------------------------------------------------------
        // Primitive memory/reputation engines
        // These remain lower-layer primitives and are NOT Workflow-aware.
        // ---------------------------------------------------------------------

        d.memoryEngine = new MemoryEngine();
        d.reputation = new ReputationEngine();

        // ---------------------------------------------------------------------
        // Policy / authorization
        // ---------------------------------------------------------------------

        d.policyBoundary = new AkmenaPolicyBoundary(address(d.core));

        d.registry = new Registry();
        d.identityImplementation = new Identity();

        d.identityFactory = new IdentityFactory(address(d.identityImplementation), address(d.registry));

        d.registry.bindIdentityFactory(address(d.identityFactory));

        d.capabilityEngine = new CapabilityEngine();
        d.delegation = new DelegationEngine();

        d.authorizationResolver =
            new AuthorizationResolver(address(d.registry), address(d.capabilityEngine), address(d.delegation));

        // ---------------------------------------------------------------------
        // Workflow + production adapters
        // ---------------------------------------------------------------------

        d.workflow = new WorkflowEngine(address(d.core), address(d.authorizationResolver));

        d.settlementAdapter = new WorkflowEconomicSettlementAdapter(address(d.workflow), address(d.economic));

        d.memoryAdapter = new WorkflowMemoryAdapter(address(d.workflow), address(d.memoryEngine));

        d.reputationAdapter = new WorkflowReputationAdapter(address(d.workflow), address(d.reputation));

        d.attestation = new AttestationEngine();

        // ---------------------------------------------------------------------
        // Additional protocol modules
        // ---------------------------------------------------------------------

        d.privacy = new PrivacyEngine();
        d.stealthRegistry = new StealthAddressRegistry();

        // ---------------------------------------------------------------------
        // Canonical module registration
        // ---------------------------------------------------------------------

        d.core.registerModule(ModuleKeys.ESCROW, address(d.escrow), "2.1.0");
        d.core.registerModule(ModuleKeys.PAYMENTS, address(d.payments), "2.0.0");
        d.core.registerModule(ModuleKeys.SETTLEMENT, address(d.settlementAdapter), "2.0.0");
        d.core.registerModule(ModuleKeys.WORKFLOW, address(d.workflow), "2.0.0");
        d.core.registerModule(ModuleKeys.MEMORY, address(d.memoryAdapter), "2.0.0");
        d.core.registerModule(ModuleKeys.REPUTATION, address(d.reputationAdapter), "2.0.0");
        d.core.registerModule(ModuleKeys.MARKETPLACE, address(d.marketplace), "2.0.0");
        d.core.registerModule(ModuleKeys.IDENTITY, address(d.identityFactory), "2.0.0");

        d.core.registerModule(keccak256("akmena.module.policy_boundary"), address(d.policyBoundary), "2.0.0");

        d.core.registerModule(keccak256("akmena.module.delegation"), address(d.delegation), "2.0.0");

        d.core.registerModule(keccak256("akmena.module.attestation"), address(d.attestation), "2.0.0");

        d.core.registerModule(keccak256("akmena.module.privacy"), address(d.privacy), "1.0.0");

        d.core.registerModule(keccak256("akmena.module.stealth_registry"), address(d.stealthRegistry), "1.0.0");

        console.log("Canonical Sprint 10 module wiring complete.");
        console.log("Core:", address(d.core));
        console.log("Escrow:", address(d.escrow));
        console.log("Payments:", address(d.payments));
        console.log("Settlement Adapter:", address(d.settlementAdapter));
        console.log("Workflow:", address(d.workflow));
        console.log("Memory Adapter:", address(d.memoryAdapter));
        console.log("Reputation Adapter:", address(d.reputationAdapter));

        vm.stopBroadcast();
    }
}
