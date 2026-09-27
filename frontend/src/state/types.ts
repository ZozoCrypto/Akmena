import type { AkmenaOnchainState } from '../data/onchain';

export type AkmenaState = AkmenaOnchainState & {
  walletConnected: boolean;
  walletAddress: `0x${string}` | undefined;

  networkStatus:
    | 'unknown'
    | 'connected'
    | 'wrong-network';

  protocolStatus:
    | 'loading'
    | 'healthy'
    | 'paused'
    | 'error';

  authorizationStatus:
    | 'loading'
    | 'live'
    | 'missing'
    | 'error';

  dataStatus:
    | 'loading'
    | 'live'
    | 'stale'
    | 'error';
};
