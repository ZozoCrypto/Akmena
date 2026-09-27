import type { Hex } from 'viem';

export const EXECUTION_INTENT_TYPES = {
  ExecutionIntent: [
    { name: 'operator', type: 'address' },
    { name: 'agent', type: 'address' },
    { name: 'target', type: 'address' },
    { name: 'selector', type: 'bytes4' },
    { name: 'calldataHash', type: 'bytes32' },
    { name: 'amount', type: 'uint256' },
    { name: 'value', type: 'uint256' },
    { name: 'proofModuleKey', type: 'bytes32' },
    { name: 'proofId', type: 'uint256' },
    { name: 'nonce', type: 'uint256' },
    { name: 'validAfter', type: 'uint256' },
    { name: 'deadline', type: 'uint256' },
  ],
} as const;

export const ZERO_BYTES32: Hex =
  '0x0000000000000000000000000000000000000000000000000000000000000000';

export const DEFAULT_VALID_AFTER_OFFSET_SECONDS = 0n;
export const DEFAULT_DEADLINE_OFFSET_SECONDS = 15n * 60n;
