// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";
import {
    IWorkflowEngine,
    WorkflowStep,
    ProtocolContext,
    IAkmenaCoreRegistry,
    ISettlementModule,
    IMemoryModule,
    IReputationModule
} from "./IWorkflowEngine.sol";

import {IAuthorizationResolver} from "../authorization/IAuthorizationResolver.sol";

import {LibWorkflowStorage} from "../storage/LibWorkflowStorage.sol";

contract WorkflowEngine is ReentrancyGuardTransient, IWorkflowEngine {
    address public immutable akmenaCore;
    IAuthorizationResolver public immutable authorizationResolver;

    uint256 private _nextWorkflowNonce = 1;

    bytes32 public constant SETTLEMENT_KEY = keccak256("akmena.module.settlement");

    bytes32 public constant MEMORY_KEY = keccak256("akmena.module.memory");

    bytes32 public constant REPUTATION_KEY = keccak256("akmena.module.reputation");

    bytes32 public constant WORKFLOW_CAPABILITY = keccak256("akmena.capability.workflow");

    event WorkflowInitialized(bytes32 indexed workflowId, uint256 indexed identityId, address indexed initiator);

    event WorkflowAdvanced(bytes32 indexed workflowId, WorkflowStep step);

    error WorkflowNotFound();
    error ModuleNotActive(bytes32 moduleKey);
    error UnauthorizedWorkflow();
    error InvalidWorkflowState(WorkflowStep expected, WorkflowStep actual);
    error InvalidCore();
    error InvalidAuthorizationResolver();
    error WorkflowAlreadyExists(bytes32 workflowId);

    constructor(address akmenaCore_, address authorizationResolver_) {
        if (akmenaCore_ == address(0) || akmenaCore_.code.length == 0) {
            revert InvalidCore();
        }

        if (authorizationResolver_ == address(0) || authorizationResolver_.code.length == 0) {
            revert InvalidAuthorizationResolver();
        }

        akmenaCore = akmenaCore_;
        authorizationResolver = IAuthorizationResolver(authorizationResolver_);
    }

    function initializeWorkflow(uint256 identityId, bytes32 agreementId, bytes32 escrowId)
        external
        override
        returns (bytes32)
    {
        authorizationResolver.requireAuthorized(identityId, msg.sender, WORKFLOW_CAPABILITY);

        LibWorkflowStorage.WorkflowStorage storage ws = LibWorkflowStorage.workflowStorage();

        uint256 nonce = _nextWorkflowNonce++;

        bytes32 workflowId = keccak256(abi.encode(address(this), identityId, msg.sender, nonce, agreementId, escrowId));

        if (workflowId == bytes32(0) || ws.workflows[workflowId].workflowId != bytes32(0)) {
            revert WorkflowAlreadyExists(workflowId);
        }

        ws.workflows[workflowId] = LibWorkflowStorage.WorkflowRecord({
            workflowId: workflowId,
            initiator: msg.sender,
            identityId: identityId,
            agreementId: agreementId,
            escrowId: escrowId,
            currentStep: WorkflowStep.Initialized
        });

        emit WorkflowInitialized(workflowId, identityId, msg.sender);

        emit WorkflowAdvanced(workflowId, WorkflowStep.Initialized);

        return workflowId;
    }

    function advanceToCompletion(
        bytes32 workflowId,
        bytes calldata settlementData,
        bytes calldata memoryData,
        bytes calldata reputationData
    ) external override nonReentrant {
        LibWorkflowStorage.WorkflowStorage storage ws = LibWorkflowStorage.workflowStorage();

        LibWorkflowStorage.WorkflowRecord storage record = ws.workflows[workflowId];

        if (record.workflowId == bytes32(0)) {
            revert WorkflowNotFound();
        }

        if (record.currentStep != WorkflowStep.Initialized) {
            revert InvalidWorkflowState(WorkflowStep.Initialized, record.currentStep);
        }

        bool authorized = authorizationResolver.isAuthorized(record.identityId, msg.sender, WORKFLOW_CAPABILITY);

        if (!authorized) {
            revert UnauthorizedWorkflow();
        }

        ProtocolContext memory ctx = ProtocolContext({actor: msg.sender, workflowId: workflowId});

        address settlementModule = _getModuleAddress(SETTLEMENT_KEY);

        ISettlementModule(settlementModule).executeSettlement(record.escrowId, settlementData, ctx);

        record.currentStep = WorkflowStep.SettlementComplete;

        emit WorkflowAdvanced(workflowId, WorkflowStep.SettlementComplete);

        address memoryModule = _getModuleAddress(MEMORY_KEY);

        IMemoryModule(memoryModule).commitMemory(record.identityId, memoryData, ctx);

        record.currentStep = WorkflowStep.MemoryCommitted;

        emit WorkflowAdvanced(workflowId, WorkflowStep.MemoryCommitted);

        address reputationModule = _getModuleAddress(REPUTATION_KEY);

        IReputationModule(reputationModule).updateReputation(record.identityId, reputationData, ctx);

        record.currentStep = WorkflowStep.ReputationUpdated;

        emit WorkflowAdvanced(workflowId, WorkflowStep.ReputationUpdated);
    }

    function _getModuleAddress(bytes32 key) internal view returns (address) {
        (address moduleAddr, bool isEnabled,) = IAkmenaCoreRegistry(akmenaCore).getModule(key);

        if (!isEnabled || moduleAddr == address(0)) {
            revert ModuleNotActive(key);
        }

        return moduleAddr;
    }
}
