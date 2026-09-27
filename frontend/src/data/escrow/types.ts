import type { Address } from 'viem';

export type EscrowLifecycle =
  | 'funded'
  | 'released'
  | 'refunded';

export type LiveEscrow = {
  id: bigint;
  buyer: Address;
  seller: Address;
  amount: bigint;
  asset: Address;
  status: EscrowLifecycle;
  blockNumber: bigint;
};

export type EscrowEventSummary = {
  created: number;
  released: number;
  refunded: number;
  active: number;
};

export type LiveEscrowState = {
  asset: Address | null;
  assetSymbol: string | null;
  assetDecimals: number | null;
  totalLocked: bigint | null;
  escrows: readonly LiveEscrow[];
  events: EscrowEventSummary;
  deploymentBlock: bigint;
  latestBlock: bigint | null;
  isLoading: boolean;
  hasError: boolean;
  refreshedAt: number | null;
};
