import type { Abi } from 'viem';

export const AKMENA_CORE_ABI = [
  {
    type: 'function',
    name: 'isPaused',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'bool' }],
  },
] as const satisfies Abi;

export const AKMENA_POLICY_BOUNDARY_ABI = [
  {
    type: 'function',
    name: 'executionAuthorization',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'address' }],
  },
] as const satisfies Abi;

export const AKMENA_EXECUTION_AUTHORIZATION_ABI = [
  {
    type: 'function',
    name: 'eip712Domain',
    stateMutability: 'view',
    inputs: [],
    outputs: [
      { name: 'fields', type: 'bytes1' },
      { name: 'name', type: 'string' },
      { name: 'version', type: 'string' },
      { name: 'chainId', type: 'uint256' },
      { name: 'verifyingContract', type: 'address' },
      { name: 'salt', type: 'bytes32' },
      { name: 'extensions', type: 'uint256[]' },
    ],
  },
] as const satisfies Abi;
