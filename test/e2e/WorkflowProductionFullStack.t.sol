// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {AkmenaCore} from "../../src/core/AkmenaCore.sol";
import {AkmenaToken} from "../../src/token/core/AkmenaToken.sol";

import {AgreementEngine} from "../../src/autonomous/AgreementEngine.sol";
import {EscrowEngine} from "../../src/economics/EscrowEngine.sol";
import {EconomicCommitmentEngine} from "../../src/economics/EconomicCommitmentEngine.sol";
import {IEconomicCommitmentEngine} from "../../src/economics/IEconomicCommitmentEngine.sol";

import {MemoryEngine} from "../../src/memory/MemoryEngine.sol";
import {ReputationEngine} from "../../src/reputation/ReputationEngine.sol";

import {WorkflowEngine} from "../../src/orchestration/WorkflowEngine.sol";
import {WorkflowStep} from "../../src/orchestration/IWorkflowEngine.sol";

import {
    WorkflowEconomicSettlementAdapter
} from "../../src/orchestration/adapters/WorkflowEconomicSettlementAdapter.sol";
import {WorkflowMemoryAdapter} from "../../src/orchestration/adapters/WorkflowMemoryAdapter.sol";
import {WorkflowReputationAdapter} from "../../src/orchestration/adapters/WorkflowReputationAdapter.sol";

import {CapabilityEngine} from "../../src/authorization/CapabilityEngine.sol";
import {DelegationEngine} from "../../src/authorization/DelegationEngine.sol";
import {AuthorizationResolver} from "../../src/authorization/AuthorizationResolver.sol";

import {Registry} from "../../src/registry/Registry.sol";
import {IdentityFactory} from "../../src/identity/IdentityFactory.sol";
import {Identity} from "../../src/identity/Identity.sol";
import {IIdentity} from "../../src/identity/IIdentity.sol";

import {ModuleKeys} from "../../src/libraries/ModuleKeys.sol";

contract WorkflowProductionFullStackTest is Test {
    uint256 internal constant AMOUNT = 100 ether;
    uint256 internal constant REPUTATION_SCORE = 777;

    address internal buyer = address(0x111);
    address internal seller = address(0x222);

    bytes32 internal constant AGREEMENT_ID = keccak256("FULLSTACK-AGREEMENT");

    AkmenaCore internal core;
    AkmenaToken internal token;

    AgreementEngine internal agreement;
    EscrowEngine internal escrow;
    EconomicCommitmentEngine internal economic;

    MemoryEngine internal memoryEngine;
    ReputationEngine internal reputationEngine;

    Registry internal registry;
    Identity internal identityImplementation;
    IdentityFactory internal factory;

    CapabilityEngine internal capabilityEngine;
    DelegationEngine internal delegation;
    AuthorizationResolver internal authorizationResolver;

    WorkflowEngine internal workflow;
    WorkflowEconomicSettlementAdapter internal settlementAdapter;
    WorkflowMemoryAdapter internal memoryAdapter;
    WorkflowReputationAdapter internal reputationAdapter;

    uint256 internal identityId;
    uint256 internal escrowId;
    bytes32 internal commitmentId;
    bytes32 internal workflowId;
    bytes32 internal memoryRoot;

    bytes32 internal constant WORKFLOW_CAPABILITY = keccak256("akmena.capability.workflow");

    function setUp() public {
        core = new AkmenaCore();
        token = new AkmenaToken(address(this));

        agreement = new AgreementEngine();
        escrow = new EscrowEngine(address(token));
        economic = new EconomicCommitmentEngine(address(agreement), address(escrow));

        memoryEngine = new MemoryEngine();
        reputationEngine = new ReputationEngine();

        registry = new Registry();
        identityImplementation = new Identity();
        factory = new IdentityFactory(address(identityImplementation), address(registry));

        registry.bindIdentityFactory(address(factory));

        capabilityEngine = new CapabilityEngine();
        delegation = new DelegationEngine();

        authorizationResolver =
            new AuthorizationResolver(address(registry), address(capabilityEngine), address(delegation));

        workflow = new WorkflowEngine(address(core), address(authorizationResolver));

        settlementAdapter = new WorkflowEconomicSettlementAdapter(address(workflow), address(economic));

        memoryAdapter = new WorkflowMemoryAdapter(address(workflow), address(memoryEngine));

        reputationAdapter = new WorkflowReputationAdapter(address(workflow), address(reputationEngine));

        // Create a real machine identity owned by buyer.
        vm.prank(buyer);
        address identity = factory.createIdentity(IIdentity.IdentityType.Machine, "");

        identityId = registry.identityId(identity);

        vm.prank(buyer);
        capabilityEngine.grantCapability(identity, WORKFLOW_CAPABILITY);

        // Canonical production module registration.
        core.registerModule(ModuleKeys.ESCROW, address(escrow), "2.1.0");

        core.registerModule(ModuleKeys.SETTLEMENT, address(settlementAdapter), "2.0.0");

        core.registerModule(ModuleKeys.WORKFLOW, address(workflow), "2.0.0");

        core.registerModule(ModuleKeys.MEMORY, address(memoryAdapter), "2.0.0");

        core.registerModule(ModuleKeys.REPUTATION, address(reputationAdapter), "2.0.0");

        // Fund buyer.
        token.transfer(buyer, AMOUNT);

        // Real agreement.
        bytes32 economicTermsHash = economic.computeEconomicTermsHash(buyer, seller, address(token), AMOUNT);

        vm.prank(buyer);
        agreement.createAgreement(AGREEMENT_ID, seller, economicTermsHash, block.timestamp + 1 days);

        vm.prank(seller);
        agreement.executeAgreement(AGREEMENT_ID);

        // Real economic commitment.
        vm.prank(buyer);
        commitmentId = economic.createCommitment(AGREEMENT_ID, address(token), AMOUNT);

        // Real escrow, bound to the commitment.
        vm.startPrank(buyer);

        token.approve(address(escrow), AMOUNT);

        escrowId = escrow.createEscrow(buyer, seller, AMOUNT, commitmentId);

        economic.attachEscrow(commitmentId, escrowId);

        vm.stopPrank();

        // Canonical release required before settlement.
        vm.prank(buyer);
        escrow.releaseEscrow(escrowId);

        memoryRoot = keccak256("FULLSTACK-MEMORY");
    }

    function test_RealWorkflowCompletesThroughAllProductionAdapters() public {
        vm.prank(buyer);

        workflowId = workflow.initializeWorkflow(identityId, AGREEMENT_ID, bytes32(escrowId));

        // The three events prove WorkflowEngine reached each production
        // adapter boundary in order.
        vm.expectEmit(false, false, false, true);
        emit WorkflowEngine.WorkflowAdvanced(workflowId, WorkflowStep.SettlementComplete);

        vm.expectEmit(false, false, false, true);
        emit WorkflowEngine.WorkflowAdvanced(workflowId, WorkflowStep.MemoryCommitted);

        vm.expectEmit(false, false, false, true);
        emit WorkflowEngine.WorkflowAdvanced(workflowId, WorkflowStep.ReputationUpdated);

        vm.prank(buyer);

        workflow.advanceToCompletion(
            workflowId, abi.encode(commitmentId), abi.encode(memoryRoot), abi.encode(REPUTATION_SCORE)
        );

        IEconomicCommitmentEngine.EconomicCommitment memory commitment = economic.getCommitment(commitmentId);

        assertEq(uint8(commitment.status), uint8(IEconomicCommitmentEngine.CommitmentStatus.Settled));

        IEconomicCommitmentEngine.EconomicSettlement memory settlement = economic.getSettlement(commitmentId);

        assertEq(settlement.escrowId, escrowId);
        assertEq(settlement.agreementId, AGREEMENT_ID);
        assertEq(settlement.payer, buyer);
        assertEq(settlement.payee, seller);
        assertEq(settlement.asset, address(token));
        assertEq(settlement.amount, AMOUNT);

        assertEq(memoryEngine.getRoot(bytes32(identityId)), memoryRoot);

        assertEq(reputationEngine.getScore(buyer), REPUTATION_SCORE);
    }

    function test_CanonicalCoreSettlementModuleIsAdapter() public view {
        (address registered, bool enabled, string memory version) = core.getModule(ModuleKeys.SETTLEMENT);

        assertEq(registered, address(settlementAdapter));
        assertTrue(enabled);
        assertEq(version, "2.0.0");

        assertTrue(registered != address(economic));
    }
}
