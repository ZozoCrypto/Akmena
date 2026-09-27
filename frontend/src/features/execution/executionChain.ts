import {
  getAddress,
  hashTypedData,
  isAddress,
  keccak256,
  type Address,
  type Hex,
  type PublicClient,
} from 'viem';

import { EXECUTION_AUTHORIZATION_ABI } from '../../abi/contracts';

import { POLICY_BOUNDARY_ABI } from '../../abi/contracts';

import { ZERO_BYTES32, EXECUTION_INTENT_TYPES } from './executionConstants';

import type { ExecutionDomain, ExecutionIntent } from './executionTypes';

export function requireAddress(value: string, label: string): Address {
  if (!isAddress(value)) {
    throw new Error(`${label} is not a valid address.`);
  }

  return getAddress(value);
}

export function requireBytes4(value: string, label: string): Hex {
  const normalized = value.toLowerCase();

  if (!/^0x[0-9a-f]{8}$/.test(normalized)) {
    throw new Error(`${label} must be exactly 4 bytes.`);
  }

  return normalized as Hex;
}

export function requireCalldata(value: string): Hex {
  const normalized = value.trim().toLowerCase();

  if (!/^0x(?:[0-9a-f]{2})*$/.test(normalized)) {
    throw new Error('Calldata must be valid even-length hexadecimal bytes.');
  }

  return normalized as Hex;
}

export function hashCalldata(calldata: Hex): Hex {
  return keccak256(calldata);
}

export async function readAuthorization(
  client: PublicClient,
  policyBoundary: Address
): Promise<Address> {
  const authorization = await client.readContract({
    address: policyBoundary,
    abi: POLICY_BOUNDARY_ABI,
    functionName: 'executionAuthorization',
  });

  return getAddress(authorization);
}

export async function readDomain(
  client: PublicClient,
  authorization: Address
): Promise<ExecutionDomain> {
  const result = await client.readContract({
    address: authorization,
    abi: EXECUTION_AUTHORIZATION_ABI,
    functionName: 'eip712Domain',
  });

  const [
    _fields,
    name,
    version,
    chainId,
    verifyingContract,
    _salt,
    _extensions,
  ] = result;

  return {
    name,
    version,
    chainId,
    verifyingContract: getAddress(verifyingContract),
  };
}

export async function readUsedNonce(
  client: PublicClient,
  authorization: Address,
  agent: Address,
  nonce: bigint
): Promise<boolean> {
  return client.readContract({
    address: authorization,
    abi: EXECUTION_AUTHORIZATION_ABI,
    functionName: 'usedNonces',
    args: [agent, nonce],
  });
}

export function buildExecutionIntent(
  input: Omit<ExecutionIntent, 'calldataHash'> & {
    calldata: Hex;
  }
): ExecutionIntent {
  return {
    operator: getAddress(input.operator),
    agent: getAddress(input.agent),
    target: getAddress(input.target),
    selector: input.selector,
    calldataHash: hashCalldata(input.calldata),
    amount: input.amount,
    value: input.value,
    proofModuleKey: input.proofModuleKey ?? ZERO_BYTES32,
    proofId: input.proofId ?? 0n,
    nonce: input.nonce,
    validAfter: input.validAfter,
    deadline: input.deadline,
  };
}

export function computeExecutionDigest(
  domain: ExecutionDomain,
  intent: ExecutionIntent
): Hex {
  return hashTypedData({
    domain: {
      name: domain.name,
      version: domain.version,
      chainId: domain.chainId,
      verifyingContract: domain.verifyingContract,
    },
    types: EXECUTION_INTENT_TYPES,
    primaryType: 'ExecutionIntent',
    message: {
      operator: intent.operator,
      agent: intent.agent,
      target: intent.target,
      selector: intent.selector,
      calldataHash: intent.calldataHash,
      amount: intent.amount,
      value: intent.value,
      proofModuleKey: intent.proofModuleKey,
      proofId: intent.proofId,
      nonce: intent.nonce,
      validAfter: intent.validAfter,
      deadline: intent.deadline,
    },
  });
}

export function assertDomain(
  domain: ExecutionDomain,
  expectedChainId: number,
  authorization: Address
): void {
  if (domain.chainId !== BigInt(expectedChainId)) {
    throw new Error(
      `EIP-712 chain mismatch: expected ${expectedChainId}, got ${domain.chainId}.`
    );
  }

  if (getAddress(domain.verifyingContract) !== getAddress(authorization)) {
    throw new Error(
      'EIP-712 verifying contract does not match live Authorization.'
    );
  }

  if (domain.name !== 'AkmenaExecutionAuthorization') {
    throw new Error(`Unexpected EIP-712 domain name: ${domain.name}`);
  }

  if (domain.version !== '1') {
    throw new Error(`Unexpected EIP-712 domain version: ${domain.version}`);
  }
}

export { EXECUTION_INTENT_TYPES };
