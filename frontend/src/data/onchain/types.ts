import type { Address } from 'viem';

export type LiveEip712Domain = {
  fields: string;
  name: string;
  version: string;
  chainId: bigint;
  verifyingContract: Address;
  salt: string;
  extensions: readonly bigint[];
};

export type AkmenaOnchainState = {
  configuredChainId: number;
  walletChainId: number | undefined;

  isExpectedWalletNetwork: boolean | null;

  coreAddress: Address;
  policyBoundaryAddress: Address;

  executionAuthorizationAddress: Address | null;

  protocolPaused: boolean | null;

  eip712Domain: LiveEip712Domain | null;

  isLoading: boolean;
  hasError: boolean;

  refreshedAt: number | null;
};
