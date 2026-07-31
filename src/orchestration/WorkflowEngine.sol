// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IWorkflowEngine, WorkflowStep, ProtocolContext, IAkmenaCoreRegistry, ISettlementModule, IMemoryModule, IReputationModule} from "./IWorkflowEngine.sol";
import {LibWorkflowStorage} from "../storage/LibWorkflowStorage.sol";

contract WorkflowEngine is IWorkflowEngine {
    address public immutable akmenaCore;

    bytes32 public constant SETTLEMENT_KEY = keccak256("akmena.module.settlement");
    bytes32 public constant MEMORY_KEY = keccak256("akmena.module.memory");
    bytes32 public constant REPUTATION_KEY = keccak256("akmena.module.reputation");

    event WorkflowInitialized(bytes32 indexed workflowId, address indexed initiator);
    event WorkflowAdvanced(bytes32 indexed workflowId, WorkflowStep step);

    error WorkflowNotFound();
    error ModuleNotActive(bytes32 moduleKey);
    error UnauthorizedInitiator();
    error InvalidWorkflowState(WorkflowStep expected, WorkflowStep actual);

    constructor(address _akmenaCore) {
        akmenaCore = _akmenaCore;
    }

    function initializeWorkflow(
        bytes32 agentIdentityId,
        bytes32 agreementId,
        bytes32 escrowId
    ) external override returns (bytes32) {
        LibWorkflowStorage.WorkflowStorage storage ws = LibWorkflowStorage.workflowStorage();
        bytes32 workflowId = keccak256(abi.encode(msg.sender, agentIdentityId, agreementId, escrowId, block.timestamp));
        
        ws.workflows[workflowId] = LibWorkflowStorage.WorkflowRecord({
            workflowId: workflowId,
            initiator: msg.sender,
            agentIdentityId: agentIdentityId,
            agreementId: agreementId,
            escrowId: escrowId,
            currentStep: WorkflowStep.Initialized
        });

        emit WorkflowInitialized(workflowId, msg.sender);
        emit WorkflowAdvanced(workflowId, WorkflowStep.Initialized);
        
        return workflowId;
    }

    function advanceToCompletion(
        bytes32 workflowId,
        bytes calldata settlementData,
        bytes calldata memoryData,
        bytes calldata reputationData
    ) external override {
        LibWorkflowStorage.WorkflowStorage storage ws = LibWorkflowStorage.workflowStorage();
        LibWorkflowStorage.WorkflowRecord storage record = ws.workflows[workflowId];

        if (record.workflowId == bytes32(0)) revert WorkflowNotFound();
        
        // 1. Layer 1 Authorization Check: Does the caller own this workflow?
        if (msg.sender != record.initiator) revert UnauthorizedInitiator();

        // 2. Strict State Machine Verification
        // (Assuming off-chain execution brings us to ExecutionFinished before this call)
        // For demonstration, we allow transition from Initialized to Settlement in this cascade
        if (record.currentStep != WorkflowStep.Initialized) {
            revert InvalidWorkflowState(WorkflowStep.Initialized, record.currentStep);
        }

        // 3. Construct the ProtocolContext payload for underlying modules
        ProtocolContext memory ctx = ProtocolContext({
            actor: msg.sender,
            workflowId: workflowId
        });

        // 4. Execute Cascade with Defense in Depth Context Forwarding
        address settlementModule = _getModuleAddress(SETTLEMENT_KEY);
        ISettlementModule(settlementModule).executeSettlement(record.escrowId, settlementData, ctx);
        record.currentStep = WorkflowStep.SettlementComplete;
        emit WorkflowAdvanced(workflowId, WorkflowStep.SettlementComplete);

        address memoryModule = _getModuleAddress(MEMORY_KEY);
        IMemoryModule(memoryModule).commitMemory(record.agentIdentityId, memoryData, ctx);
        record.currentStep = WorkflowStep.MemoryCommitted;
        emit WorkflowAdvanced(workflowId, WorkflowStep.MemoryCommitted);

        address reputationModule = _getModuleAddress(REPUTATION_KEY);
        IReputationModule(reputationModule).updateReputation(record.agentIdentityId, reputationData, ctx);
        record.currentStep = WorkflowStep.ReputationUpdated;
        emit WorkflowAdvanced(workflowId, WorkflowStep.ReputationUpdated);
    }

    function _getModuleAddress(bytes32 key) internal view returns (address) {
        (address moduleAddr, bool isEnabled, ) = IAkmenaCoreRegistry(akmenaCore).getModule(key);
        if (!isEnabled || moduleAddr == address(0)) revert ModuleNotActive(key);
        return moduleAddr;
    }
}
