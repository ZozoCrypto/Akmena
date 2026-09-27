import type { Address, Hex } from 'viem';

import type {
  ExecutionDomain,
  ExecutionIntent,
} from '../execution/executionTypes';

export type ApprovalSecurityCheck = {
  id:
    | 'network'
    | 'operator'
    | 'agent'
    | 'target'
    | 'selector'
    | 'calldata'
    | 'amount'
    | 'native-value'
    | 'proof'
    | 'nonce'
    | 'validity'
    | 'eip712';

  label: string;
  status: 'pass' | 'pending' | 'warning' | 'fail';
  detail: string;
};

export type ApprovalModel = {
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

  domain: ExecutionDomain;
  digest: Hex;

  networkLabel: string;

  securityChecks: readonly ApprovalSecurityCheck[];
};

export function createApprovalModel(
  intent: ExecutionIntent,
  domain: ExecutionDomain,
  digest: Hex,
  expectedChainId: number,
  expectedAuthorization: Address,
): ApprovalModel {
  const domainMatchesChain =
    domain.chainId === BigInt(expectedChainId);

  const domainMatchesAuthorization =
    domain.verifyingContract.toLowerCase() ===
    expectedAuthorization.toLowerCase();

  const now = BigInt(Math.floor(Date.now() / 1000));

  const validityStatus =
    now < intent.validAfter
      ? 'pending'
      : now > intent.deadline
        ? 'fail'
        : 'pass';

  return {
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

    domain,
    digest,

    networkLabel:
      domainMatchesChain
        ? `Chain ${domain.chainId.toString()}`
        : `Unexpected chain ${domain.chainId.toString()}`,

    securityChecks: [
      {
        id: 'network',
        label: 'Network',
        status: domainMatchesChain ? 'pass' : 'fail',
        detail: domainMatchesChain
          ? 'EIP-712 domain matches the configured network.'
          : 'EIP-712 domain does not match the configured network.',
      },
      {
        id: 'operator',
        label: 'Operator',
        status: 'pass',
        detail: 'Intent contains an explicit operator.',
      },
      {
        id: 'agent',
        label: 'Agent',
        status: 'pass',
        detail: 'Intent is bound to one agent address.',
      },
      {
        id: 'target',
        label: 'Target',
        status: 'pass',
        detail: 'Execution is bound to one destination contract.',
      },
      {
        id: 'selector',
        label: 'Selector',
        status: 'pass',
        detail: 'Function selector is explicitly signed.',
      },
      {
        id: 'calldata',
        label: 'Calldata',
        status: 'pass',
        detail: 'Exact calldata hash is explicitly signed.',
      },
      {
        id: 'amount',
        label: 'Amount',
        status: intent.amount > 0n ? 'pass' : 'warning',
        detail:
          intent.amount > 0n
            ? 'Economic amount is explicitly signed.'
            : 'Intent carries a zero economic amount.',
      },
      {
        id: 'native-value',
        label: 'Native value',
        status: 'pass',
        detail: 'Native value is explicitly signed.',
      },
      {
        id: 'proof',
        label: 'Proof',
        status: 'pass',
        detail:
          intent.proofId === 0n
            ? 'No external proof ID is attached.'
            : 'Proof module and proof ID are explicitly bound.',
      },
      {
        id: 'nonce',
        label: 'Nonce',
        status: 'pass',
        detail: `Execution nonce #${intent.nonce.toString()}.`,
      },
      {
        id: 'validity',
        label: 'Validity',
        status: validityStatus,
        detail:
          validityStatus === 'pass'
            ? 'Intent is currently inside its validity window.'
            : validityStatus === 'pending'
              ? 'Intent is not active yet.'
              : 'Intent validity window has expired.',
      },
      {
        id: 'eip712',
        label: 'EIP-712',
        status:
          domainMatchesChain && domainMatchesAuthorization
            ? 'pass'
            : 'fail',
        detail:
          domainMatchesChain && domainMatchesAuthorization
            ? 'Typed-data domain is available and internally consistent.'
            : 'Typed-data domain requires verification.',
      },
    ],
  };
}
