export const ESCROW_ENGINE_ABI = [
  {
    "type": "function",
    "name": "createEscrow",
    "inputs": [
      { "name": "buyer", "type": "address", "internalType": "address" },
      { "name": "seller", "type": "address", "internalType": "address" },
      { "name": "amount", "type": "uint256", "internalType": "uint256" }
    ],
    "outputs": [{ "name": "", "type": "uint256", "internalType": "uint256" }],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "getEscrow",
    "inputs": [{ "name": "escrowId", "type": "uint256", "internalType": "uint256" }],
    "outputs": [
      {
        "name": "",
        "type": "tuple",
        "internalType": "struct LibStorage.EscrowData",
        "components": [
          { "name": "buyer", "type": "address", "internalType": "address" },
          { "name": "seller", "type": "address", "internalType": "address" },
          { "name": "amount", "type": "uint256", "internalType": "uint256" },
          { "name": "status", "type": "uint8", "internalType": "uint8" }
        ]
      }
    ],
    "stateMutability": "view"
  }
] as const;

export const POLICY_BOUNDARY_ABI = [
  {
    "type": "function",
    "name": "setAgentPolicy",
    "inputs": [
      { "name": "agent", "type": "address", "internalType": "address" },
      { "name": "maxSpendPerTx", "type": "uint256", "internalType": "uint256" },
      { "name": "maxSpendTotal", "type": "uint256", "internalType": "uint256" },
      { "name": "requiresProof", "type": "bool", "internalType": "bool" }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  }
] as const;

export const PRIVACY_ENGINE_ABI = [
  {
    "type": "function",
    "name": "nullifiers",
    "inputs": [{ "name": "", "type": "bytes32", "internalType": "bytes32" }],
    "outputs": [{ "name": "", "type": "bool", "internalType": "bool" }],
    "stateMutability": "view"
  }
] as const;


export const EXECUTION_AUTHORIZATION_ABI = [
  {
    type: "function",
    name: "EXECUTION_INTENT_TYPEHASH",
    inputs: [],
    outputs: [{ name: "", type: "bytes32" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "eip712Domain",
    inputs: [],
    outputs: [
      { name: "fields", type: "bytes1" },
      { name: "name", type: "string" },
      { name: "version", type: "string" },
      { name: "chainId", type: "uint256" },
      { name: "verifyingContract", type: "address" },
      { name: "salt", type: "bytes32" },
      { name: "extensions", type: "uint256[]" },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "hashIntent",
    inputs: [
      {
        name: "intent",
        type: "tuple",
        components: [
          { name: "operator", type: "address" },
          { name: "agent", type: "address" },
          { name: "target", type: "address" },
          { name: "selector", type: "bytes4" },
          { name: "calldataHash", type: "bytes32" },
          { name: "amount", type: "uint256" },
          { name: "value", type: "uint256" },
          { name: "proofModuleKey", type: "bytes32" },
          { name: "proofId", type: "uint256" },
          { name: "nonce", type: "uint256" },
          { name: "validAfter", type: "uint256" },
          { name: "deadline", type: "uint256" },
        ],
      },
    ],
    outputs: [{ name: "", type: "bytes32" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "usedNonces",
    inputs: [
      { name: "", type: "address" },
      { name: "", type: "uint256" },
    ],
    outputs: [{ name: "", type: "bool" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "verifyAndConsume",
    inputs: [
      {
        name: "intent",
        type: "tuple",
        components: [
          { name: "operator", type: "address" },
          { name: "agent", type: "address" },
          { name: "target", type: "address" },
          { name: "selector", type: "bytes4" },
          { name: "calldataHash", type: "bytes32" },
          { name: "amount", type: "uint256" },
          { name: "value", type: "uint256" },
          { name: "proofModuleKey", type: "bytes32" },
          { name: "proofId", type: "uint256" },
          { name: "nonce", type: "uint256" },
          { name: "validAfter", type: "uint256" },
          { name: "deadline", type: "uint256" },
        ],
      },
      { name: "signature", type: "bytes" },
    ],
    outputs: [{ name: "signer", type: "address" }],
    stateMutability: "nonpayable",
  },
] as const;
