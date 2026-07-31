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

/// @notice Extensible context payload passed from the Orchestrator down to Modules
struct ProtocolContext {
    address actor;
    bytes32 workflowId;
    // Future V3 expansion:
    // bytes signature;
    // uint256 deadline;
    // uint256 nonce;
}

interface IWorkflowEngine {
    function initializeWorkflow(bytes32 agentIdentityId, bytes32 agreementId, bytes32 escrowId) external returns (bytes32);
    function advanceToCompletion(bytes32 workflowId, bytes calldata settlementData, bytes calldata memoryData, bytes calldata reputationData) external;
}

interface IAkmenaCoreRegistry {
    function getModule(bytes32 key) external view returns (address, bool, string memory);
}

// Note: Modules now explicitly require the ProtocolContext for independent authorization
interface ISettlementModule {
    function executeSettlement(bytes32 escrowId, bytes calldata data, ProtocolContext calldata ctx) external;
}

interface IMemoryModule {
    function commitMemory(bytes32 agentId, bytes calldata data, ProtocolContext calldata ctx) external;
}

interface IReputationModule {
    function updateReputation(bytes32 agentId, bytes calldata data, ProtocolContext calldata ctx) external;
}
