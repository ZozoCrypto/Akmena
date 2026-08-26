export const ESCROW_ENGINE_ABI = [
  {
    "type": "function",
    "name": "createEscrow",
    "inputs": [
      { "name": "seller", "type": "address" },
      { "name": "amount", "type": "uint256" }
    ],
    "outputs": [{ "name": "escrowId", "type": "uint256" }],
    "stateMutability": "payable"
  },
  {
    "type": "function",
    "name": "getEscrow",
    "inputs": [{ "name": "escrowId", "type": "uint256" }],
    "outputs": [
      {
        "type": "tuple",
        "components": [
          { "name": "buyer", "type": "address" },
          { "name": "seller", "type": "address" },
          { "name": "amount", "type": "uint256" },
          { "name": "status", "type": "uint8" }
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
      { "name": "agent", "type": "address" },
      { "name": "maxSpendPerTx", "type": "uint256" },
      { "name": "maxSpendTotal", "type": "uint256" },
      { "name": "requiresProof", "type": "bool" }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  }
] as const;

export const PRIVACY_ENGINE_ABI = [
  {
    "type": "function",
    "name": "nullifiers",
    "inputs": [{ "name": "", "type": "bytes32" }],
    "outputs": [{ "name": "", "type": "bool" }],
    "stateMutability": "view"
  }
] as const;
