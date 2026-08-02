export declare const WorkflowEngineABI: readonly [{
    readonly type: "constructor";
    readonly inputs: readonly [{
        readonly name: "_akmenaCore";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "MEMORY_KEY";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "REPUTATION_KEY";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "SETTLEMENT_KEY";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "advanceToCompletion";
    readonly inputs: readonly [{
        readonly name: "workflowId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "settlementData";
        readonly type: "bytes";
        readonly internalType: "bytes";
    }, {
        readonly name: "memoryData";
        readonly type: "bytes";
        readonly internalType: "bytes";
    }, {
        readonly name: "reputationData";
        readonly type: "bytes";
        readonly internalType: "bytes";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "akmenaCore";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "initializeWorkflow";
    readonly inputs: readonly [{
        readonly name: "agentIdentityId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "agreementId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "escrowId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "event";
    readonly name: "WorkflowAdvanced";
    readonly inputs: readonly [{
        readonly name: "workflowId";
        readonly type: "bytes32";
        readonly indexed: true;
        readonly internalType: "bytes32";
    }, {
        readonly name: "step";
        readonly type: "uint8";
        readonly indexed: false;
        readonly internalType: "enum WorkflowStep";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "WorkflowInitialized";
    readonly inputs: readonly [{
        readonly name: "workflowId";
        readonly type: "bytes32";
        readonly indexed: true;
        readonly internalType: "bytes32";
    }, {
        readonly name: "initiator";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }];
    readonly anonymous: false;
}, {
    readonly type: "error";
    readonly name: "InvalidWorkflowState";
    readonly inputs: readonly [{
        readonly name: "expected";
        readonly type: "uint8";
        readonly internalType: "enum WorkflowStep";
    }, {
        readonly name: "actual";
        readonly type: "uint8";
        readonly internalType: "enum WorkflowStep";
    }];
}, {
    readonly type: "error";
    readonly name: "ModuleNotActive";
    readonly inputs: readonly [{
        readonly name: "moduleKey";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
}, {
    readonly type: "error";
    readonly name: "UnauthorizedInitiator";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "WorkflowNotFound";
    readonly inputs: readonly [];
}];
