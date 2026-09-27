import {
  createContext,
  type ReactNode,
  useContext,
  useMemo,
} from 'react';
import { useAccount } from 'wagmi';

import { useAkmenaOnchainState } from '../data/onchain';
import type { AkmenaState } from './types';

const AkmenaStateContext =
  createContext<AkmenaState | null>(null);

export function AkmenaStateProvider({
  children,
}: {
  children: ReactNode;
}) {
  const { address, isConnected } = useAccount();

  const onchain = useAkmenaOnchainState();

  const value = useMemo<AkmenaState>(() => {
    const walletConnected =
      isConnected && Boolean(address);

    const networkStatus =
      onchain.isExpectedWalletNetwork === null
        ? 'unknown'
        : onchain.isExpectedWalletNetwork
          ? 'connected'
          : 'wrong-network';

    const protocolStatus =
      onchain.isLoading
        ? 'loading'
        : onchain.hasError
          ? 'error'
          : onchain.protocolPaused === true
            ? 'paused'
            : 'healthy';

    const authorizationStatus =
      onchain.isLoading &&
      !onchain.executionAuthorizationAddress
        ? 'loading'
        : onchain.hasError
          ? 'error'
          : onchain.executionAuthorizationAddress
            ? 'live'
            : 'missing';

    const dataStatus =
      onchain.isLoading
        ? 'loading'
        : onchain.hasError
          ? 'error'
          : onchain.refreshedAt &&
              Date.now() - onchain.refreshedAt > 60_000
            ? 'stale'
            : 'live';

    return {
      ...onchain,

      walletConnected,
      walletAddress: address,

      networkStatus,

      protocolStatus,
      authorizationStatus,
      dataStatus,
    };
  }, [
    address,
    isConnected,
    onchain,
  ]);

  return (
    <AkmenaStateContext.Provider value={value}>
      {children}
    </AkmenaStateContext.Provider>
  );
}

export function useAkmenaState(): AkmenaState {
  const context = useContext(AkmenaStateContext);

  if (!context) {
    throw new Error(
      'useAkmenaState must be used inside AkmenaStateProvider.',
    );
  }

  return context;
}
