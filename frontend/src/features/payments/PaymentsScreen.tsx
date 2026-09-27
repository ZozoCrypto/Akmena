import {
  ArrowDownLeft,
  ArrowUpRight,
  Box,
  Coins,
  ExternalLink,
  LockKeyhole,
  RefreshCw,
  ShieldCheck,
} from 'lucide-react';
import { formatUnits } from 'viem';

import { Panel } from '../../components/ui/Panel';
import { StatusPill } from '../../components/status/StatusPill';
import { CONTRACT_ADDRESSES, NETWORK_CONFIG } from '../../config';
import { useEscrowState } from '../../data/escrow';

function shortAddress(
  value?: string | null,
): string {
  if (!value) return 'Unavailable';
  return `${value.slice(0, 6)}...${value.slice(-4)}`;
}

function formatTokenAmount(
  amount: bigint | null,
  decimals: number | null,
): string {
  if (amount === null) return 'Unavailable';
  if (decimals === null) return amount.toString();

  return formatUnits(amount, decimals);
}

function lifecycleLabel(
  status: 'funded' | 'released' | 'refunded',
): string {
  switch (status) {
    case 'released':
      return 'Released';
    case 'refunded':
      return 'Refunded';
    default:
      return 'Funded';
  }
}

export function PaymentsScreen() {
  const escrow = useEscrowState();

  const assetLabel =
    escrow.assetSymbol ?? 'Custody asset';

  const lockedAmount = formatTokenAmount(
    escrow.totalLocked,
    escrow.assetDecimals,
  );

  return (
    <div className="space-y-6">
      <section className="rounded-3xl border border-white/7 bg-[radial-gradient(circle_at_top_right,rgba(34,211,238,0.07),transparent_38%),rgba(255,255,255,0.018)] px-6 py-7 sm:px-8 sm:py-9">
        <div className="flex flex-col justify-between gap-6 lg:flex-row lg:items-end">
          <div>
            <div className="flex flex-wrap items-center gap-2">
              <span className="text-[10px] font-semibold uppercase tracking-[0.22em] text-cyan-300/70">
                Payments & Escrow
              </span>

              <StatusPill
                label={
                  escrow.hasError
                    ? 'Data error'
                    : escrow.isLoading
                      ? 'Reading chain'
                      : 'Live on-chain'
                }
                status={
                  escrow.hasError
                    ? 'danger'
                    : escrow.isLoading
                      ? 'active'
                      : 'success'
                }
              />
            </div>

            <h1 className="mt-3 text-3xl font-semibold tracking-tight text-white sm:text-4xl">
              Money committed.
              <br />
              <span className="text-zinc-500">
                Verified at the custody boundary.
              </span>
            </h1>

            <p className="mt-4 max-w-2xl text-sm leading-7 text-zinc-500">
              Escrow data here comes from the deployed EscrowEngine:
              the custody asset, aggregate locked value, and escrow
              lifecycle events. Application state is never treated as
              proof of custody.
            </p>
          </div>

          <div className="rounded-2xl border border-white/6 bg-black/20 p-5 lg:min-w-[300px]">
            <div className="text-[10px] font-semibold uppercase tracking-[0.18em] text-zinc-600">
              Currently locked
            </div>

            <div className="mt-3 flex items-end gap-2">
              <div className="text-4xl font-semibold tracking-tight text-white">
                {lockedAmount}
              </div>

              <div className="pb-1 text-sm font-medium text-cyan-200">
                {assetLabel}
              </div>
            </div>

            <div className="mt-2 text-xs text-zinc-600">
              Authoritative `totalLocked()` read
            </div>
          </div>
        </div>
      </section>

      <section className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        <Panel eyebrow="Custody" title="Total locked">
          <div className="mt-4 flex items-center gap-3">
            <LockKeyhole className="h-5 w-5 text-cyan-200" />
            <div>
              <div className="text-2xl font-semibold text-white">
                {lockedAmount}
              </div>
              <div className="mt-1 text-xs text-zinc-600">
                {assetLabel}
              </div>
            </div>
          </div>
        </Panel>

        <Panel eyebrow="Escrow" title="Active">
          <div className="mt-4 flex items-center gap-3">
            <Box className="h-5 w-5 text-amber-200" />
            <div>
              <div className="text-2xl font-semibold text-white">
                {escrow.events.active}
              </div>
              <div className="mt-1 text-xs text-zinc-600">
                Derived from lifecycle events
              </div>
            </div>
          </div>
        </Panel>

        <Panel eyebrow="Lifecycle" title="Created">
          <div className="mt-4 flex items-center gap-3">
            <ArrowUpRight className="h-5 w-5 text-zinc-400" />
            <div>
              <div className="text-2xl font-semibold text-white">
                {escrow.events.created}
              </div>
              <div className="mt-1 text-xs text-zinc-600">
                Since deployment block
              </div>
            </div>
          </div>
        </Panel>

        <Panel eyebrow="Settlement" title="Terminal">
          <div className="mt-4 flex items-center gap-4">
            <div>
              <div className="text-sm font-medium text-white">
                {escrow.events.released} released
              </div>
              <div className="mt-1 text-xs text-zinc-600">
                {escrow.events.refunded} refunded
              </div>
            </div>

            <Coins className="ml-auto h-5 w-5 text-zinc-500" />
          </div>
        </Panel>
      </section>

      <section className="grid gap-5 xl:grid-cols-[0.72fr_1.28fr]">
        <Panel
          eyebrow="Custody asset"
          title="What is actually being held"
        >
          <div className="space-y-3">
            <div className="rounded-2xl border border-white/6 bg-white/[0.018] p-5">
              <div className="text-[10px] uppercase tracking-[0.18em] text-zinc-600">
                Asset contract
              </div>
              <div className="mt-2 break-all font-mono text-xs text-zinc-300">
                {escrow.asset ?? 'Unavailable'}
              </div>
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div className="rounded-2xl border border-white/6 bg-white/[0.018] p-4">
                <div className="text-[10px] uppercase tracking-[0.18em] text-zinc-600">
                  Symbol
                </div>
                <div className="mt-2 text-sm font-medium text-white">
                  {escrow.assetSymbol ?? 'Unavailable'}
                </div>
              </div>

              <div className="rounded-2xl border border-white/6 bg-white/[0.018] p-4">
                <div className="text-[10px] uppercase tracking-[0.18em] text-zinc-600">
                  Decimals
                </div>
                <div className="mt-2 text-sm font-medium text-white">
                  {escrow.assetDecimals ?? 'Unavailable'}
                </div>
              </div>
            </div>

            <div className="rounded-2xl border border-emerald-300/10 bg-emerald-300/[0.025] p-5">
              <div className="flex items-start gap-3">
                <ShieldCheck className="mt-0.5 h-5 w-5 text-emerald-200" />
                <div>
                  <div className="text-sm font-medium text-white">
                    Custody is read from the contract
                  </div>
                  <div className="mt-1 text-xs leading-6 text-zinc-600">
                    The aggregate committed value comes directly from
                    `totalLocked()`. It is not reconstructed from the
                    frontend.
                  </div>
                </div>
              </div>
            </div>
          </div>
        </Panel>

        <Panel
          eyebrow="Verified lifecycle"
          title="Escrow activity"
        >
          {escrow.escrows.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-12 text-center">
              <RefreshCw className="h-6 w-6 text-zinc-700" />
              <div className="mt-4 text-sm font-medium text-zinc-400">
                {escrow.isLoading
                  ? 'Reading escrow history…'
                  : 'No escrow creation events found'}
              </div>
              <div className="mt-2 max-w-md text-xs leading-6 text-zinc-600">
                Lifecycle data begins at the authoritative deployment
                block and is read directly from Base Sepolia logs.
              </div>
            </div>
          ) : (
            <div className="space-y-2">
              {escrow.escrows
                .slice(0, 12)
                .map((item) => (
                  <div
                    key={item.id.toString()}
                    className="rounded-2xl border border-white/6 bg-white/[0.018] p-4"
                  >
                    <div className="flex items-start justify-between gap-4">
                      <div className="min-w-0">
                        <div className="flex items-center gap-2">
                          <span className="text-sm font-medium text-white">
                            Escrow #{item.id.toString()}
                          </span>

                          <StatusPill
                            label={lifecycleLabel(
                              item.status,
                            )}
                            status={
                              item.status === 'funded'
                                ? 'warning'
                                : 'neutral'
                            }
                          />
                        </div>

                        <div className="mt-2 text-xs text-zinc-600">
                          Buyer {shortAddress(item.buyer)}
                        </div>

                        <div className="mt-1 text-xs text-zinc-600">
                          Seller {shortAddress(item.seller)}
                        </div>
                      </div>

                      <div className="shrink-0 text-right">
                        <div className="text-sm font-semibold text-white">
                          {formatTokenAmount(
                            item.amount,
                            escrow.assetDecimals,
                          )}
                        </div>
                        <div className="mt-1 text-xs text-zinc-600">
                          {assetLabel}
                        </div>
                      </div>
                    </div>
                  </div>
                ))}
            </div>
          )}
        </Panel>
      </section>

      <div className="flex flex-wrap items-center gap-x-5 gap-y-2 border-t border-white/6 pt-4 text-xs text-zinc-700">
        <span>
          Escrow {shortAddress(CONTRACT_ADDRESSES.escrowEngine)}
        </span>
        <span>
          Chain {NETWORK_CONFIG.chainId}
        </span>
        <span>
          History from block {escrow.deploymentBlock.toString()}
        </span>

        <a
          href={`${NETWORK_CONFIG.blockExplorer}/address/${CONTRACT_ADDRESSES.escrowEngine}`}
          target="_blank"
          rel="noreferrer"
          className="ml-auto inline-flex items-center gap-1.5 text-zinc-500 transition hover:text-zinc-300"
        >
          View contract
          <ExternalLink className="h-3 w-3" />
        </a>
      </div>
    </div>
  );
}
