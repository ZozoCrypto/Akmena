import { useCallback, useMemo, useState } from 'react';

import { useAccount, usePublicClient, useSignTypedData } from 'wagmi';

import {
  getAddress,
  parseEther,
  recoverTypedDataAddress,
  type Address,
  type Hex,
} from 'viem';

import { CONTRACT_ADDRESSES, NETWORK_CONFIG } from '../../config';

import {
  EXECUTION_AUTHORIZATION_ABI,
  POLICY_BOUNDARY_ABI,
} from '../../abi/contracts';

import {
  DEFAULT_DEADLINE_OFFSET_SECONDS,
  DEFAULT_VALID_AFTER_OFFSET_SECONDS,
  EXECUTION_INTENT_TYPES,
  ZERO_BYTES32,
} from './executionConstants';

import {
  assertDomain,
  buildExecutionIntent,
  computeExecutionDigest,
  hashCalldata,
  readAuthorization,
  readDomain,
  readUsedNonce,
  requireAddress,
  requireBytes4,
  requireCalldata,
} from './executionChain';

import type { ExecutionDomain, ExecutionIntent } from './executionTypes';

type BuildInput = {
  agent: string;
  target: string;
  selector: string;
  calldata: string;
  amount: string;
  value: string;
};

export function useExecutionIntent() {
  const { address: operator } = useAccount();

  const publicClient = usePublicClient();

  const { signTypedDataAsync } = useSignTypedData();

  const [intent, setIntent] = useState<ExecutionIntent | null>(null);

  const [domain, setDomain] = useState<ExecutionDomain | null>(null);

  const [authorization, setAuthorization] = useState<Address | null>(null);

  const [digest, setDigest] = useState<Hex | null>(null);

  const [signature, setSignature] = useState<Hex | null>(null);

  const [recoveredSigner, setRecoveredSigner] = useState<Address | null>(null);

  const [error, setError] = useState<string | null>(null);

  const [loading, setLoading] = useState(false);

  const build = useCallback(
    async (input: BuildInput) => {
      setError(null);
      setLoading(true);

      try {
        if (!operator) {
          throw new Error(
            'Connect a wallet before creating an execution intent.'
          );
        }

        if (!publicClient) {
          throw new Error('Public client is unavailable.');
        }

        const chainId = await publicClient.getChainId();

        if (chainId !== NETWORK_CONFIG.chainId) {
          throw new Error(
            `Wrong network: expected Base Sepolia (${NETWORK_CONFIG.chainId}), got ${chainId}.`
          );
        }

        const agent = requireAddress(input.agent, 'Agent');

        const target = requireAddress(input.target, 'Target');

        const selector = requireBytes4(input.selector, 'Selector');

        const calldata = requireCalldata(input.calldata);

        const amount = parseEther(input.amount || '0');

        const value = parseEther(input.value || '0');

        const auth = await readAuthorization(
          publicClient,
          CONTRACT_ADDRESSES.policyBoundary as Address
        );

        const liveDomain = await readDomain(publicClient, auth);

        assertDomain(liveDomain, NETWORK_CONFIG.chainId, auth);

        let nonce = 0n;

        while (await readUsedNonce(publicClient, auth, agent, nonce)) {
          nonce += 1n;
        }

        const now = BigInt(Math.floor(Date.now() / 1000));

        const execution = buildExecutionIntent({
          operator: getAddress(operator),
          agent,
          target,
          selector,
          calldata,
          amount,
          value,
          proofModuleKey: ZERO_BYTES32,
          proofId: 0n,
          nonce,
          validAfter: now + DEFAULT_VALID_AFTER_OFFSET_SECONDS,
          deadline: now + DEFAULT_DEADLINE_OFFSET_SECONDS,
        });

        const computedDigest = computeExecutionDigest(liveDomain, execution);

        setAuthorization(auth);
        setDomain(liveDomain);
        setIntent(execution);
        setDigest(computedDigest);
        setSignature(null);
        setRecoveredSigner(null);

        return {
          authorization: auth,
          domain: liveDomain,
          intent: execution,
          digest: computedDigest,
        };
      } catch (cause) {
        const message =
          cause instanceof Error
            ? cause.message
            : 'Unable to build execution intent.';

        setError(message);
        throw cause;
      } finally {
        setLoading(false);
      }
    },
    [operator, publicClient]
  );

  const sign = useCallback(async () => {
    setError(null);

    try {
      if (!operator) {
        throw new Error('Connect a wallet before signing an execution intent.');
      }

      if (!intent || !domain || !digest) {
        throw new Error('Build an execution intent before signing.');
      }

      const normalizedWallet = getAddress(operator);
      const normalizedOperator = getAddress(intent.operator);

      if (normalizedWallet.toLowerCase() !== normalizedOperator.toLowerCase()) {
        throw new Error('Connected wallet does not match intent.operator.');
      }

      const typedDomain = {
        name: domain.name,
        version: domain.version,
        chainId: domain.chainId,
        verifyingContract: domain.verifyingContract,
      };

      const typedMessage = {
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
      };

      const typedSignature = await signTypedDataAsync({
        domain: typedDomain,
        types: EXECUTION_INTENT_TYPES,
        primaryType: 'ExecutionIntent',
        message: typedMessage,
      });

      const recovered = await recoverTypedDataAddress({
        domain: typedDomain,
        types: EXECUTION_INTENT_TYPES,
        primaryType: 'ExecutionIntent',
        message: typedMessage,
        signature: typedSignature,
      });

      const normalizedRecovered = getAddress(recovered);

      if (
        normalizedRecovered.toLowerCase() !== normalizedOperator.toLowerCase()
      ) {
        throw new Error(
          `Signature signer mismatch: expected ${normalizedOperator}, recovered ${normalizedRecovered}.`
        );
      }

      setSignature(typedSignature);
      setRecoveredSigner(normalizedRecovered);

      return {
        signature: typedSignature,
        recoveredSigner: normalizedRecovered,
        digest,
      };
    } catch (cause) {
      const message =
        cause instanceof Error
          ? cause.message
          : 'Unable to sign execution intent.';

      setError(message);
      throw cause;
    }
  }, [operator, intent, domain, digest, signTypedDataAsync]);

  return useMemo(
    () => ({
      intent,
      domain,
      authorization,
      digest,
      error,
      loading,
      build,
      sign,
    }),
    [intent, domain, authorization, digest, error, loading, build, sign]
  );
}
