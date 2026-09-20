// AUTO-GENERATED FROM FOUNDRY ARTIFACT
// Source: /home/cryptozozo/projects/akmena/out/EconomicCommitmentEngine.sol/EconomicCommitmentEngine.json
// DO NOT EDIT MANUALLY.

export const EconomicCommitmentEngineABI = [
  {
    "type": "constructor",
    "inputs": [
      {
        "name": "agreementEngine_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "escrowEngine_",
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "ECONOMIC_TERMS_TYPEHASH",
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
    "name": "SETTLEMENT_TYPEHASH",
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
    "name": "agreementEngine",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "contract IAgreementEngine"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "attachEscrow",
    "inputs": [
      {
        "name": "commitmentId",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "escrowId",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "computeEconomicTermsHash",
    "inputs": [
      {
        "name": "payer",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "payee",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "asset",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "amount",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "createCommitment",
    "inputs": [
      {
        "name": "agreementId",
        "type": "bytes32",
        "internalType": "bytes32"
      },
      {
        "name": "asset_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "amount",
        "type": "uint256",
        "internalType": "uint256"
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
    "type": "function",
    "name": "escrowEngine",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "contract IEscrowEngine"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "finalizeRefund",
    "inputs": [
      {
        "name": "commitmentId",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "finalizeSettlement",
    "inputs": [
      {
        "name": "numericEscrowId",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "commitmentId",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "getCommitment",
    "inputs": [
      {
        "name": "commitmentId",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "tuple",
        "internalType": "struct IEconomicCommitmentEngine.EconomicCommitment",
        "components": [
          {
            "name": "commitmentId",
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
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "payer",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "payee",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "asset",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "amount",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "termsHash",
            "type": "bytes32",
            "internalType": "bytes32"
          },
          {
            "name": "status",
            "type": "uint8",
            "internalType": "enum IEconomicCommitmentEngine.CommitmentStatus"
          }
        ]
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "getSettlement",
    "inputs": [
      {
        "name": "commitmentId",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "tuple",
        "internalType": "struct IEconomicCommitmentEngine.EconomicSettlement",
        "components": [
          {
            "name": "settlementId",
            "type": "bytes32",
            "internalType": "bytes32"
          },
          {
            "name": "commitmentId",
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
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "payer",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "payee",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "asset",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "amount",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "timestamp",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "event",
    "name": "EconomicCommitmentCreated",
    "inputs": [
      {
        "name": "commitmentId",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "agreementId",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "payer",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "payee",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      },
      {
        "name": "asset",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      },
      {
        "name": "amount",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "EconomicEscrowAttached",
    "inputs": [
      {
        "name": "commitmentId",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "escrowId",
        "type": "uint256",
        "indexed": true,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "EconomicRefundFinalized",
    "inputs": [
      {
        "name": "commitmentId",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "escrowId",
        "type": "uint256",
        "indexed": true,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "EconomicSettlementRecorded",
    "inputs": [
      {
        "name": "settlementId",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "commitmentId",
        "type": "bytes32",
        "indexed": true,
        "internalType": "bytes32"
      },
      {
        "name": "escrowId",
        "type": "uint256",
        "indexed": true,
        "internalType": "uint256"
      },
      {
        "name": "payer",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      },
      {
        "name": "payee",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      },
      {
        "name": "amount",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "error",
    "name": "AgreementExpired",
    "inputs": []
  },
  {
    "type": "error",
    "name": "AgreementNotExecuted",
    "inputs": []
  },
  {
    "type": "error",
    "name": "AgreementNotFound",
    "inputs": []
  },
  {
    "type": "error",
    "name": "CommitmentAlreadyExists",
    "inputs": []
  },
  {
    "type": "error",
    "name": "CommitmentNotFound",
    "inputs": []
  },
  {
    "type": "error",
    "name": "EconomicTermsMismatch",
    "inputs": []
  },
  {
    "type": "error",
    "name": "EscrowCommitmentMismatch",
    "inputs": []
  },
  {
    "type": "error",
    "name": "EscrowNotFunded",
    "inputs": []
  },
  {
    "type": "error",
    "name": "EscrowStateMismatch",
    "inputs": []
  },
  {
    "type": "error",
    "name": "InvalidAddress",
    "inputs": []
  },
  {
    "type": "error",
    "name": "InvalidAmount",
    "inputs": []
  },
  {
    "type": "error",
    "name": "InvalidCommitmentStatus",
    "inputs": []
  },
  {
    "type": "error",
    "name": "InvalidDependency",
    "inputs": []
  },
  {
    "type": "error",
    "name": "SettlementAlreadyFinalized",
    "inputs": []
  },
  {
    "type": "error",
    "name": "SettlementNotReleased",
    "inputs": []
  },
  {
    "type": "error",
    "name": "UnauthorizedCommitment",
    "inputs": []
  }
] as const;
