// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {AkmenaCore} from "../../src/core/AkmenaCore.sol";
import {AkmenaToken} from "../../src/token/core/AkmenaToken.sol";
import {EscrowEngine} from "../../src/economics/EscrowEngine.sol";
import {AgreementEngine} from "../../src/autonomous/AgreementEngine.sol";
import {EconomicCommitmentEngine} from "../../src/economics/EconomicCommitmentEngine.sol";
import {PaymentsEngine} from "../../src/economics/PaymentsEngine.sol";

import {MemoryEngine} from "../../src/memory/MemoryEngine.sol";
import {ReputationEngine} from "../../src/reputation/ReputationEngine.sol";

import {ProtocolContext} from "../../src/orchestration/IWorkflowEngine.sol";

import {
    WorkflowEconomicSettlementAdapter
} from "../../src/orchestration/adapters/WorkflowEconomicSettlementAdapter.sol";
import {WorkflowMemoryAdapter} from "../../src/orchestration/adapters/WorkflowMemoryAdapter.sol";
import {WorkflowReputationAdapter} from "../../src/orchestration/adapters/WorkflowReputationAdapter.sol";

import {ModuleKeys} from "../../src/libraries/ModuleKeys.sol";

contract WorkflowCaller {
    function commitMemory(
        WorkflowMemoryAdapter adapter,
        uint256 identityId,
        bytes calldata data,
        ProtocolContext calldata ctx
    ) external {
        adapter.commitMemory(identityId, data, ctx);
    }

    function updateReputation(
        WorkflowReputationAdapter adapter,
        uint256 identityId,
        bytes calldata data,
        ProtocolContext calldata ctx
    ) external {
        adapter.updateReputation(identityId, data, ctx);
    }
}

contract WorkflowProductionAdaptersTest is Test {
    AkmenaCore internal core;
    AkmenaToken internal token;
    EscrowEngine internal escrow;
    AgreementEngine internal agreement;
    EconomicCommitmentEngine internal economic;
    PaymentsEngine internal payments;

    MemoryEngine internal memoryEngine;
    ReputationEngine internal reputationEngine;

    WorkflowEconomicSettlementAdapter internal settlementAdapter;
    WorkflowMemoryAdapter internal memoryAdapter;
    WorkflowReputationAdapter internal reputationAdapter;

    WorkflowCaller internal caller;

    address internal actor = address(0xBEEF);
    uint256 internal constant IDENTITY_ID = 42;

    function setUp() public {
        core = new AkmenaCore();
        token = new AkmenaToken(address(this));

        escrow = new EscrowEngine(address(token));
        agreement = new AgreementEngine();
        economic = new EconomicCommitmentEngine(address(agreement), address(escrow));
        payments = new PaymentsEngine();

        memoryEngine = new MemoryEngine();
        reputationEngine = new ReputationEngine();

        caller = new WorkflowCaller();

        settlementAdapter = new WorkflowEconomicSettlementAdapter(address(caller), address(economic));

        memoryAdapter = new WorkflowMemoryAdapter(address(caller), address(memoryEngine));

        reputationAdapter = new WorkflowReputationAdapter(address(caller), address(reputationEngine));
    }

    function test_MemoryAdapterTranslatesWorkflowCall() public {
        bytes32 rootHash = keccak256("memory-root");

        ProtocolContext memory ctx = ProtocolContext({actor: actor, workflowId: keccak256("workflow-1")});

        caller.commitMemory(memoryAdapter, IDENTITY_ID, abi.encode(rootHash), ctx);

        assertEq(memoryEngine.getRoot(bytes32(IDENTITY_ID)), rootHash);
    }

    function test_MemoryAdapterRejectsDirectCaller() public {
        bytes32 rootHash = keccak256("memory-root");

        ProtocolContext memory ctx = ProtocolContext({actor: actor, workflowId: keccak256("workflow-1")});

        vm.expectRevert(WorkflowMemoryAdapter.UnauthorizedWorkflow.selector);

        memoryAdapter.commitMemory(IDENTITY_ID, abi.encode(rootHash), ctx);
    }

    function test_ReputationAdapterUsesWorkflowActor() public {
        uint256 score = 777;

        ProtocolContext memory ctx = ProtocolContext({actor: actor, workflowId: keccak256("workflow-2")});

        caller.updateReputation(reputationAdapter, IDENTITY_ID, abi.encode(score), ctx);

        assertEq(reputationEngine.getScore(actor), score);
    }

    function test_ReputationAdapterRejectsDirectCaller() public {
        ProtocolContext memory ctx = ProtocolContext({actor: actor, workflowId: keccak256("workflow-2")});

        vm.expectRevert(WorkflowReputationAdapter.UnauthorizedWorkflow.selector);

        reputationAdapter.updateReputation(IDENTITY_ID, abi.encode(uint256(100)), ctx);
    }

    function test_CanonicalModuleRegistrationShape() public {
        core.registerModule(ModuleKeys.ESCROW, address(escrow), "2.1.0");

        core.registerModule(ModuleKeys.PAYMENTS, address(payments), "2.0.0");

        core.registerModule(ModuleKeys.SETTLEMENT, address(settlementAdapter), "2.0.0");

        core.registerModule(ModuleKeys.MEMORY, address(memoryAdapter), "2.0.0");

        core.registerModule(ModuleKeys.REPUTATION, address(reputationAdapter), "2.0.0");

        (address settlementAddress, bool settlementEnabled, string memory settlementVersion) =
            core.getModule(ModuleKeys.SETTLEMENT);

        assertEq(settlementAddress, address(settlementAdapter));
        assertTrue(settlementEnabled);
        assertEq(settlementVersion, "2.0.0");

        (address memoryAddress, bool memoryEnabled, string memory memoryVersion) = core.getModule(ModuleKeys.MEMORY);

        assertEq(memoryAddress, address(memoryAdapter));
        assertTrue(memoryEnabled);
        assertEq(memoryVersion, "2.0.0");

        (address reputationAddress, bool reputationEnabled, string memory reputationVersion) =
            core.getModule(ModuleKeys.REPUTATION);

        assertEq(reputationAddress, address(reputationAdapter));
        assertTrue(reputationEnabled);
        assertEq(reputationVersion, "2.0.0");
    }
}
