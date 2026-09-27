import { ReactNode, useState } from 'react';
import { OnchainKitProvider } from '@coinbase/onchainkit';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { base, baseSepolia } from 'wagmi/chains';
import { http, createConfig, WagmiProvider } from 'wagmi';
import { coinbaseWallet, metaMask, injected } from 'wagmi/connectors';

// Configure Wagmi for Base (Mainnet) and Base Sepolia testnet
const wagmiConfig = createConfig({
  chains: [baseSepolia, base],
  connectors: [
    coinbaseWallet({
      appName: 'Akmena Singularity',
      preference: 'all',
    }),
    metaMask(),
    injected(),
  ],
  transports: {
    [baseSepolia.id]: http(),
    [base.id]: http(),
  },
});

export function OnchainProviders({ children }: { children: ReactNode }) {
  const [queryClient] = useState(() => new QueryClient());

  return (
    <WagmiProvider config={wagmiConfig}>
      <QueryClientProvider client={queryClient}>
        <OnchainKitProvider
          chain={baseSepolia}
        >
          {children}
        </OnchainKitProvider>
      </QueryClientProvider>
    </WagmiProvider>
  );
}
