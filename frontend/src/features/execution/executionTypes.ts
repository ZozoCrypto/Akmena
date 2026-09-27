import type { Address, Hex } from 'viem';

export type ExecutionIntent = {
  operator: Address;
  agent: Address;
  target: Address;
  selector: Hex;
  calldataHash: Hex;
  amount: bigint;
  value: bigint;
  proofModuleKey: Hex;
  proofId: bigint;
  nonce: bigint;
  validAfter: bigint;
  deadline: bigint;
};

export type ExecutionDomain = {
  name: string;
  version: string;
  chainId: bigint;
  verifyingContract: Address;
};

export type PreparedExecution = {
  intent: ExecutionIntent;
  calldata: Hex;
  authorization: Address;
  domain: ExecutionDomain;
  digest: Hex;
};
