// AUTO-GENERATED FROM FOUNDRY ARTIFACT
// Source: /home/cryptozozo/projects/akmena/out/MarketplaceEngine.sol/MarketplaceEngine.json
// DO NOT EDIT MANUALLY.

export const MarketplaceEngineABI = [
  {
    "type": "function",
    "name": "assignTask",
    "inputs": [
      {
        "name": "taskId",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "assignee",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "completeTask",
    "inputs": [
      {
        "name": "taskId",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "caller",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "createTask",
    "inputs": [
      {
        "name": "reward",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "getTask",
    "inputs": [
      {
        "name": "taskId",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "tuple",
        "internalType": "struct LibStorage.TaskData",
        "components": [
          {
            "name": "creator",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "assignee",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "reward",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "status",
            "type": "uint8",
            "internalType": "uint8"
          }
        ]
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "event",
    "name": "TaskAssigned",
    "inputs": [
      {
        "name": "taskId",
        "type": "uint256",
        "indexed": true,
        "internalType": "uint256"
      },
      {
        "name": "assignee",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "TaskCompleted",
    "inputs": [
      {
        "name": "taskId",
        "type": "uint256",
        "indexed": true,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "TaskCreated",
    "inputs": [
      {
        "name": "taskId",
        "type": "uint256",
        "indexed": true,
        "internalType": "uint256"
      },
      {
        "name": "creator",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "reward",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "error",
    "name": "InvalidAddress",
    "inputs": []
  },
  {
    "type": "error",
    "name": "TaskNotAssigned",
    "inputs": []
  },
  {
    "type": "error",
    "name": "TaskNotFound",
    "inputs": []
  },
  {
    "type": "error",
    "name": "TaskNotOpen",
    "inputs": []
  },
  {
    "type": "error",
    "name": "UnauthorizedAccess",
    "inputs": []
  }
] as const;
