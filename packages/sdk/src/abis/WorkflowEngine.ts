export const WorkflowEngineABI = [
  {
    "type": "constructor",
    "inputs": [
      {
        "name": "_akmenaCore",
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "MEMORY_KEY",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "REPUTATION_KEY",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "SETTLEMENT_KEY",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "advanceToCompletion",
    "inputs": [
      {
        "name": "workflowId",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "settlementData",
        "type": "bytes",
        "internalType": "bytes"
      },
      {
        "name": "memoryData",
        "type": "bytes",
        "internalType": "bytes"
      },
      {
        "name": "reputationData",
        "type": "bytes",
        "internalType": "bytes"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "akmenaCore",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "initializeWorkflow",
    "inputs": [
      {
        "name": "agentIdentityId",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "agreementId",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "escrowId",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "nonpayable"
  },
  {
    "type": "event",
    "name": "WorkflowAdvanced",
    "inputs": [
      {
        "name": "workflowId",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "step",
        "type": "uint8",
        "indexed": false,
        "internalType": "enum WorkflowStep"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "WorkflowInitialized",
    "inputs": [
      {
        "name": "workflowId",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "initiator",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "error",
    "name": "InvalidWorkflowState",
    "inputs": [
      {
        "name": "expected",
        "type": "uint8",
        "internalType": "enum WorkflowStep"
      },
      {
        "name": "actual",
        "type": "uint8",
        "internalType": "enum WorkflowStep"
      }
    ]
  },
  {
    "type": "error",
    "name": "ModuleNotActive",
    "inputs": [
      {
        "name": "moduleKey",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ]
  },
  {
    "type": "error",
    "name": "UnauthorizedInitiator",
    "inputs": []
  },
  {
    "type": "error",
    "name": "WorkflowNotFound",
    "inputs": []
  }
] as const;
