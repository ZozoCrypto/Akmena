import { useMemo } from 'react';
import { useChainId, useReadContract } from 'wagmi';
import type { Address } from 'viem';

import { CONTRACT_ADDRESSES, NETWORK_CONFIG } from '../../config';
import {
  AKMENA_CORE_ABI,
  AKMENA_EXECUTION_AUTHORIZATION_ABI,
  AKMENA_POLICY_BOUNDARY_ABI,
} from './abis';
import type {
  AkmenaOnchainState,
  LiveEip712Domain,
} from './types';

function normalizeDomain(value: unknown): LiveEip712Domain | null {
  if (!Array.isArray(value) || value.length < 7) {
    return null;
  }

  const [
    fields,
    name,
    version,
    chainId,
    verifyingContract,
    salt,
    extensions,
  ] = value;

  if (
    typeof fields !== 'string' ||
    typeof name !== 'string' ||
    typeof version !== 'string' ||
    typeof chainId !== 'bigint' ||
    typeof verifyingContract !== 'string' ||
    typeof salt !== 'string' ||
    !Array.isArray(extensions)
  ) {
    return null;
  }

  return {
    fields,
    name,
    version,
    chainId,
    verifyingContract: verifyingContract as Address,
    salt,
    extensions: extensions.filter(
      (extension): extension is bigint => typeof extension === 'bigint',
    ),
  };
}

export function useAkmenaOnchainState(): AkmenaOnchainState {
  const walletChainId = useChainId();

  const coreAddress = CONTRACT_ADDRESSES.akmenaCore as Address;
  const policyBoundaryAddress =
    CONTRACT_ADDRESSES.policyBoundary as Address;

  const coreRead = useReadContract({
    address: coreAddress,
    abi: AKMENA_CORE_ABI,
    functionName: 'isPaused',
    query: {
      staleTime: 5_000,
      refetchInterval: 12_000,
    },
  });

  const authorizationRead = useReadContract({
    address: policyBoundaryAddress,
    abi: AKMENA_POLICY_BOUNDARY_ABI,
    functionName: 'executionAuthorization',
    query: {
      staleTime: 30_000,
      refetchInterval: 30_000,
    },
  });

  const executionAuthorizationAddress =
    authorizationRead.data as Address | undefined;

  const domainRead = useReadContract({
    address: executionAuthorizationAddress,
    abi: AKMENA_EXECUTION_AUTHORIZATION_ABI,
    functionName: 'eip712Domain',
    query: {
      enabled: Boolean(executionAuthorizationAddress),
      staleTime: 30_000,
      refetchInterval: 30_000,
    },
  });

  return useMemo(() => {
    const isExpectedWalletNetwork =
      walletChainId === undefined
        ? null
        : walletChainId === NETWORK_CONFIG.chainId;

    const eip712Domain = normalizeDomain(domainRead.data);

    return {
      configuredChainId: NETWORK_CONFIG.chainId,
      walletChainId,

      isExpectedWalletNetwork,

      coreAddress,
      policyBoundaryAddress,

      executionAuthorizationAddress:
        executionAuthorizationAddress ?? null,

      protocolPaused:
        typeof coreRead.data === 'boolean'
          ? coreRead.data
          : null,

      eip712Domain,

      isLoading:
        coreRead.isLoading ||
        authorizationRead.isLoading ||
        domainRead.isLoading,

      hasError:
        Boolean(coreRead.error) ||
        Boolean(authorizationRead.error) ||
        Boolean(domainRead.error),

      refreshedAt:
        coreRead.dataUpdatedAt > 0
          ? coreRead.dataUpdatedAt
          : authorizationRead.dataUpdatedAt > 0
            ? authorizationRead.dataUpdatedAt
            : domainRead.dataUpdatedAt > 0
              ? domainRead.dataUpdatedAt
              : null,
    };
  }, [
    authorizationRead.data,
    authorizationRead.dataUpdatedAt,
    authorizationRead.error,
    authorizationRead.isLoading,
    coreAddress,
    coreRead.data,
    coreRead.dataUpdatedAt,
    coreRead.error,
    coreRead.isLoading,
    domainRead.data,
    domainRead.dataUpdatedAt,
    domainRead.error,
    domainRead.isLoading,
    executionAuthorizationAddress,
    policyBoundaryAddress,
    walletChainId,
  ]);
}
