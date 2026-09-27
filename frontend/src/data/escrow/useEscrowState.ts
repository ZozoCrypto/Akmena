import { useMemo } from 'react';
import type { Address } from 'viem';
import { usePublicClient, useReadContract } from 'wagmi';
import { useQuery } from '@tanstack/react-query';

import { CONTRACT_ADDRESSES, NETWORK_CONFIG } from '../../config';
import {
  ERC20_METADATA_ABI,
  ESCROW_ABI,
} from './escrowAbi';
import type {
  EscrowLifecycle,
  LiveEscrow,
  LiveEscrowState,
} from './types';

const escrowAddress =
  CONTRACT_ADDRESSES.escrowEngine as Address;

/*
 * Authoritative deployment block from the current Base Sepolia
 * deployment registry.
 *
 * Do not derive historical scope from the current block alone:
 * the deployment block is the lower bound for lifecycle discovery.
 */
const DEPLOYMENT_BLOCK = 46106393n;

function lifecycleFromStatus(
  status: number,
): EscrowLifecycle | null {
  switch (status) {
    case 1:
      return 'funded';
    case 2:
      return 'released';
    case 3:
      return 'refunded';
    default:
      return null;
  }
}

function formatSafeAddress(
  value: unknown,
): Address | null {
  return typeof value === 'string'
    ? (value as Address)
    : null;
}

export function useEscrowState(): LiveEscrowState {
  const publicClient = usePublicClient();

  const totalLockedRead = useReadContract({
    address: escrowAddress,
    abi: ESCROW_ABI,
    functionName: 'totalLocked',
    query: {
      staleTime: 5_000,
      refetchInterval: 10_000,
    },
  });

  const assetRead = useReadContract({
    address: escrowAddress,
    abi: ESCROW_ABI,
    functionName: 'asset',
    query: {
      staleTime: 30_000,
      refetchInterval: 30_000,
    },
  });

  const asset = formatSafeAddress(assetRead.data);

  const symbolRead = useReadContract({
    address: asset ?? undefined,
    abi: ERC20_METADATA_ABI,
    functionName: 'symbol',
    query: {
      enabled: Boolean(asset),
      staleTime: 60_000,
      refetchInterval: 60_000,
    },
  });

  const decimalsRead = useReadContract({
    address: asset ?? undefined,
    abi: ERC20_METADATA_ABI,
    functionName: 'decimals',
    query: {
      enabled: Boolean(asset),
      staleTime: 60_000,
      refetchInterval: 60_000,
    },
  });

  const historyQuery = useQuery({
    queryKey: [
      'akmena',
      'escrow',
      'history',
      escrowAddress,
      NETWORK_CONFIG.chainId,
    ],
    enabled:
      Boolean(publicClient) &&
      NETWORK_CONFIG.chainId === 84532,
    staleTime: 5_000,
    refetchInterval: 10_000,
    queryFn: async () => {
      if (!publicClient) {
        throw new Error(
          'No live public client is available.',
        );
      }

      const latestBlock =
        await publicClient.getBlockNumber();

      const [
        createdLogs,
        releasedLogs,
        refundedLogs,
      ] = await Promise.all([
        publicClient.getLogs({
          address: escrowAddress,
          event: {
            type: 'event',
            name: 'EscrowCreated',
            inputs: [
              {
                indexed: true,
                name: 'escrowId',
                type: 'uint256',
              },
              {
                indexed: true,
                name: 'buyer',
                type: 'address',
              },
              {
                indexed: true,
                name: 'seller',
                type: 'address',
              },
              {
                indexed: false,
                name: 'amount',
                type: 'uint256',
              },
            ],
          },
          fromBlock: DEPLOYMENT_BLOCK,
          toBlock: latestBlock,
        }),
        publicClient.getLogs({
          address: escrowAddress,
          event: {
            type: 'event',
            name: 'EscrowReleased',
            inputs: [
              {
                indexed: true,
                name: 'escrowId',
                type: 'uint256',
              },
            ],
          },
          fromBlock: DEPLOYMENT_BLOCK,
          toBlock: latestBlock,
        }),
        publicClient.getLogs({
          address: escrowAddress,
          event: {
            type: 'event',
            name: 'EscrowRefunded',
            inputs: [
              {
                indexed: true,
                name: 'escrowId',
                type: 'uint256',
              },
            ],
          },
          fromBlock: DEPLOYMENT_BLOCK,
          toBlock: latestBlock,
        }),
      ]);

      const released = new Set(
        releasedLogs
          .map((log) =>
            log.args.escrowId === undefined
              ? null
              : log.args.escrowId,
          )
          .filter(
            (id): id is bigint =>
              id !== null,
          ),
      );

      const refunded = new Set(
        refundedLogs
          .map((log) =>
            log.args.escrowId === undefined
              ? null
              : log.args.escrowId,
          )
          .filter(
            (id): id is bigint =>
              id !== null,
          ),
      );

      const escrows: LiveEscrow[] = [];

      for (const log of createdLogs) {
        const id = log.args.escrowId;
        const buyer = log.args.buyer;
        const seller = log.args.seller;
        const amount = log.args.amount;

        if (
          id === undefined ||
          !buyer ||
          !seller ||
          amount === undefined
        ) {
          continue;
        }

        let status: EscrowLifecycle = 'funded';

        if (released.has(id)) {
          status = 'released';
        } else if (refunded.has(id)) {
          status = 'refunded';
        }

        if (!asset) {
          /*
           * The live event gives the economic participants and amount,
           * but the custody asset is authoritative from asset().
           * Do not invent an asset when that read is unavailable.
           */
          continue;
        }

        escrows.push({
          id,
          buyer,
          seller,
          amount,
          asset,
          status,
          blockNumber: log.blockNumber,
        });
      }

      escrows.sort(
        (a, b) =>
          Number(b.blockNumber - a.blockNumber),
      );

      return {
        escrows,
        latestBlock,
        created: createdLogs.length,
        released: releasedLogs.length,
        refunded: refundedLogs.length,
      };
    },
  });

  return useMemo(
    () => ({
      asset,
      assetSymbol:
        typeof symbolRead.data === 'string'
          ? symbolRead.data
          : null,
      assetDecimals:
        typeof decimalsRead.data === 'number'
          ? decimalsRead.data
          : null,
      totalLocked:
        typeof totalLockedRead.data === 'bigint'
          ? totalLockedRead.data
          : null,
      escrows:
        historyQuery.data?.escrows ?? [],
      events: {
        created:
          historyQuery.data?.created ?? 0,
        released:
          historyQuery.data?.released ?? 0,
        refunded:
          historyQuery.data?.refunded ?? 0,
        active:
          historyQuery.data?.escrows.filter(
            (escrow) =>
              escrow.status === 'funded',
          ).length ?? 0,
      },
      deploymentBlock: DEPLOYMENT_BLOCK,
      latestBlock:
        historyQuery.data?.latestBlock ?? null,
      isLoading:
        totalLockedRead.isLoading ||
        assetRead.isLoading ||
        Boolean(asset) &&
          (symbolRead.isLoading ||
            decimalsRead.isLoading) ||
        historyQuery.isLoading,
      hasError:
        Boolean(totalLockedRead.error) ||
        Boolean(assetRead.error) ||
        Boolean(symbolRead.error) ||
        Boolean(decimalsRead.error) ||
        Boolean(historyQuery.error),
      refreshedAt:
        Math.max(
          totalLockedRead.dataUpdatedAt,
          assetRead.dataUpdatedAt,
          symbolRead.dataUpdatedAt,
          decimalsRead.dataUpdatedAt,
          historyQuery.dataUpdatedAt,
        ) || null,
    }),
    [
      asset,
      assetRead.dataUpdatedAt,
      assetRead.error,
      assetRead.isLoading,
      decimalsRead.data,
      decimalsRead.dataUpdatedAt,
      decimalsRead.error,
      decimalsRead.isLoading,
      historyQuery.data,
      historyQuery.dataUpdatedAt,
      historyQuery.error,
      historyQuery.isLoading,
      symbolRead.data,
      symbolRead.dataUpdatedAt,
      symbolRead.error,
      symbolRead.isLoading,
      totalLockedRead.data,
      totalLockedRead.dataUpdatedAt,
      totalLockedRead.error,
      totalLockedRead.isLoading,
    ],
  );
}
