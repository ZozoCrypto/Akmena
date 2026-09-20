// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

enum WorkflowStep {
    Initialized,
    AgreementAccepted,
    EscrowFunded,
    ExecutionStarted,
    ExecutionFinished,
    SettlementComplete,
    MemoryCommitted,
    ReputationUpdated
}

struct ProtocolContext {
    address actor;
    bytes32 workflowId;
}

interface IWorkflowEngine {
    function initializeWorkflow(uint256 identityId, bytes32 agreementId, bytes32 escrowId) external returns (bytes32);

    function advanceToCompletion(
        bytes32 workflowId,
        bytes calldata settlementData,
        bytes calldata memoryData,
        bytes calldata reputationData
    ) external;
}

interface IAkmenaCoreRegistry {
    function getModule(bytes32 key) external view returns (address, bool, string memory);
}

interface ISettlementModule {
    function executeSettlement(bytes32 escrowId, bytes calldata data, ProtocolContext calldata ctx) external;
}

interface IMemoryModule {
    function commitMemory(uint256 identityId, bytes calldata data, ProtocolContext calldata ctx) external;
}

interface IReputationModule {
    function updateReputation(uint256 identityId, bytes calldata data, ProtocolContext calldata ctx) external;
}
