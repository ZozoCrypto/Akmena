import {
  Activity,
  ArrowRight,
  CheckCircle2,
  Clock3,
  Fingerprint,
  Globe2,
  LockKeyhole,
  ShieldCheck,
  Wallet,
  Wifi,
  XCircle,
} from 'lucide-react';

import { Panel } from '../../components/ui/Panel';
import { StatusPill } from '../../components/status/StatusPill';
import { useAkmenaState } from '../../state';
import { useApprovalRequests } from '../approvals/ApprovalRequestProvider';

function shortAddress(value?: string | null): string {
  if (!value) return 'Not connected';
  return `${value.slice(0, 6)}...${value.slice(-4)}`;
}

function formatRefreshTime(timestamp?: number | null): string {
  if (!timestamp) return 'Not available';

  return new Date(timestamp).toLocaleTimeString([], {
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  });
}

function statusLabel(
  status:
    | 'loading'
    | 'healthy'
    | 'paused'
    | 'error'
    | 'live'
    | 'missing'
    | 'stale'
    | 'wrong-network'
    | 'connected'
    | 'unknown',
): string {
  switch (status) {
    case 'healthy':
    case 'live':
    case 'connected':
      return 'Healthy';
    case 'paused':
      return 'Paused';
    case 'wrong-network':
      return 'Wrong network';
    case 'missing':
      return 'Missing';
    case 'stale':
      return 'Stale';
    case 'error':
      return 'Error';
    case 'loading':
      return 'Loading';
    default:
      return 'Unavailable';
  }
}

function statusTone(
  status:
    | 'loading'
    | 'healthy'
    | 'paused'
    | 'error'
    | 'live'
    | 'missing'
    | 'stale'
    | 'wrong-network'
    | 'connected'
    | 'unknown',
): 'success' | 'warning' | 'danger' | 'active' | 'neutral' {
  switch (status) {
    case 'healthy':
    case 'live':
    case 'connected':
      return 'success';
    case 'paused':
    case 'wrong-network':
    case 'stale':
      return 'warning';
    case 'error':
    case 'missing':
      return 'danger';
    case 'loading':
      return 'active';
    default:
      return 'neutral';
  }
}

function DataState({
  label,
  value,
  detail,
}: {
  label: string;
  value: string;
  detail?: string;
}) {
  return (
    <div className="rounded-2xl border border-white/6 bg-white/[0.018] p-5">
      <div className="text-[10px] font-semibold uppercase tracking-[0.18em] text-zinc-600">
        {label}
      </div>
      <div className="mt-2 break-all text-sm font-medium text-white">
        {value}
      </div>
      {detail && (
        <div className="mt-1 text-xs leading-5 text-zinc-600">
          {detail}
        </div>
      )}
    </div>
  );
}

export function OverviewScreen() {
  const akmena = useAkmenaState();
  const { pendingRequests } = useApprovalRequests();

  const networkReady =
    akmena.networkStatus === 'connected' &&
    akmena.isExpectedWalletNetwork;

  const protocolHealthy =
    akmena.protocolStatus === 'healthy';

  const authorizationLive =
    akmena.authorizationStatus === 'live' &&
    Boolean(akmena.executionAuthorizationAddress);

  const liveBoundaryReady =
    networkReady &&
    protocolHealthy &&
    authorizationLive &&
    !akmena.protocolPaused;

  return (
    <div className="space-y-6">
      <section className="rounded-3xl border border-white/7 bg-[radial-gradient(circle_at_top_right,rgba(34,211,238,0.08),transparent_38%),rgba(255,255,255,0.018)] px-6 py-7 shadow-2xl shadow-black/10 sm:px-8 sm:py-9">
        <div className="flex flex-col justify-between gap-6 xl:flex-row xl:items-end">
          <div className="max-w-3xl">
            <div className="flex flex-wrap items-center gap-2">
              <span className="text-[10px] font-semibold uppercase tracking-[0.22em] text-cyan-300/70">
                Autonomous Economic Infrastructure
              </span>

              <StatusPill
                label={
                  liveBoundaryReady
                    ? 'Execution boundary live'
                    : 'Boundary requires attention'
                }
                status={
                  liveBoundaryReady
                    ? 'success'
                    : 'warning'
                }
              />
            </div>

            <h1 className="mt-4 max-w-3xl text-3xl font-semibold tracking-tight text-white sm:text-4xl">
              Your agents can act.
              <br />
              <span className="text-zinc-500">
                Akmena makes the action explicit.
              </span>
            </h1>

            <p className="mt-4 max-w-2xl text-sm leading-7 text-zinc-500">
              The Overview shows verified protocol state, the connected
              operator, authorization boundary, and actions waiting for
              human approval. Economic activity appears here only when
              Akmena can establish it from live state.
            </p>
          </div>

          <div className="grid min-w-[260px] gap-3 sm:grid-cols-2 xl:w-[360px]">
            <DataState
              label="Network"
              value={
                akmena.walletConnected
                  ? networkReady
                    ? 'Base Sepolia'
                    : `Chain ${akmena.walletChainId ?? 'unknown'}`
                  : 'Not connected'
              }
              detail={`Configured chain ${akmena.configuredChainId}`}
            />

            <DataState
              label="Operator"
              value={shortAddress(akmena.walletAddress)}
              detail={
                akmena.walletConnected
                  ? 'Connected wallet'
                  : 'Connect a wallet to sign'
              }
            />
          </div>
        </div>
      </section>

      <section className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        <Panel eyebrow="Protocol" title="Protocol health">
          <div className="mt-5 flex items-center justify-between gap-4">
            <div className="flex items-center gap-3">
              {protocolHealthy ? (
                <CheckCircle2 className="h-5 w-5 text-emerald-200" />
              ) : (
                <XCircle className="h-5 w-5 text-amber-200" />
              )}
              <div>
                <div className="text-sm font-medium text-white">
                  {statusLabel(akmena.protocolStatus)}
                </div>
                <div className="mt-1 text-xs text-zinc-600">
                  Core pause state:{' '}
                  {akmena.protocolPaused
                    ? 'paused'
                    : 'running'}
                </div>
              </div>
            </div>

            <StatusPill
              label={
                akmena.protocolPaused
                  ? 'Paused'
                  : protocolHealthy
                    ? 'Healthy'
                    : statusLabel(akmena.protocolStatus)
              }
              status={
                akmena.protocolPaused
                  ? 'warning'
                  : statusTone(akmena.protocolStatus)
              }
            />
          </div>
        </Panel>

        <Panel eyebrow="Authorization" title="Execution boundary">
          <div className="mt-5 flex items-center justify-between gap-4">
            <div className="flex items-center gap-3">
              <LockKeyhole className="h-5 w-5 text-cyan-200" />
              <div>
                <div className="text-sm font-medium text-white">
                  {authorizationLive
                    ? 'Live authorization'
                    : statusLabel(akmena.authorizationStatus)}
                </div>
                <div className="mt-1 text-xs text-zinc-600">
                  {shortAddress(
                    akmena.executionAuthorizationAddress,
                  )}
                </div>
              </div>
            </div>

            <StatusPill
              label={
                authorizationLive
                  ? 'Live'
                  : statusLabel(akmena.authorizationStatus)
              }
              status={statusTone(akmena.authorizationStatus)}
            />
          </div>
        </Panel>

        <Panel eyebrow="Approvals" title="Waiting for you">
          <div className="mt-5 flex items-center justify-between gap-4">
            <div>
              <div className="text-3xl font-semibold tracking-tight text-white">
                {pendingRequests.length}
              </div>
              <div className="mt-1 text-xs text-zinc-600">
                Local approval requests
              </div>
            </div>

            <div className="flex h-10 w-10 items-center justify-center rounded-xl border border-amber-300/10 bg-amber-300/[0.035]">
              <Clock3 className="h-5 w-5 text-amber-200/80" />
            </div>
          </div>
        </Panel>

        <Panel eyebrow="Data" title="State freshness">
          <div className="mt-5 flex items-center justify-between gap-4">
            <div>
              <div className="text-sm font-medium text-white">
                {statusLabel(akmena.dataStatus)}
              </div>
              <div className="mt-1 text-xs text-zinc-600">
                Last refresh{' '}
                {formatRefreshTime(
                  akmena.refreshedAt,
                )}
              </div>
            </div>

            <Wifi
              className="h-5 w-5 text-zinc-500"
            />
          </div>
        </Panel>
      </section>

      <section className="grid gap-5 xl:grid-cols-[1.2fr_0.8fr]">
        <Panel
          eyebrow="Execution boundary"
          title="What is protecting value right now"
        >
          <div className="mt-5 grid gap-3 sm:grid-cols-2">
            <DataState
              label="Core"
              value={shortAddress(akmena.coreAddress)}
              detail="Live protocol pause state"
            />

            <DataState
              label="Policy boundary"
              value={shortAddress(akmena.policyBoundaryAddress)}
              detail="Execution boundary contract"
            />

            <DataState
              label="EIP-712 domain"
              value={
                akmena.eip712Domain
                  ? akmena.eip712Domain.name
                  : 'Unavailable'
              }
              detail={
                akmena.eip712Domain
                  ? `v${akmena.eip712Domain.version} · chain ${akmena.eip712Domain.chainId}`
                  : 'Live domain has not been read'
              }
            />

            <DataState
              label="Verifier"
              value={
                akmena.eip712Domain?.verifyingContract
                  ? shortAddress(
                      akmena.eip712Domain
                        .verifyingContract,
                    )
                  : 'Unavailable'
              }
              detail="EIP-712 verifying contract"
            />
          </div>

          <div className="mt-5 rounded-2xl border border-white/6 bg-black/20 p-5">
            <div className="flex items-start gap-3">
              <ShieldCheck className="mt-0.5 h-5 w-5 shrink-0 text-emerald-200" />

              <div>
                <div className="text-sm font-medium text-white">
                  Explicit execution remains the boundary
                </div>
                <div className="mt-1 text-xs leading-6 text-zinc-600">
                  The Overview does not submit transactions, invent
                  execution history, or infer economic balances from
                  application state.
                </div>
              </div>
            </div>
          </div>
        </Panel>

        <Panel
          eyebrow="What needs attention"
          title="Human control"
        >
          <div className="space-y-3">
            <div className="rounded-2xl border border-white/6 bg-white/[0.018] p-5">
              <div className="flex items-start gap-3">
                <Wallet className="mt-0.5 h-5 w-5 text-zinc-400" />
                <div className="min-w-0">
                  <div className="text-sm font-medium text-white">
                    Operator
                  </div>
                  <div className="mt-1 text-xs leading-6 text-zinc-600">
                    {akmena.walletConnected
                      ? `Connected as ${shortAddress(
                          akmena.walletAddress,
                        )}`
                      : 'Connect a wallet before signing any economic intent.'}
                  </div>
                </div>
              </div>
            </div>

            <div className="rounded-2xl border border-white/6 bg-white/[0.018] p-5">
              <div className="flex items-start gap-3">
                <Activity className="mt-0.5 h-5 w-5 text-zinc-400" />
                <div className="min-w-0">
                  <div className="text-sm font-medium text-white">
                    Approval queue
                  </div>
                  <div className="mt-1 text-xs leading-6 text-zinc-600">
                    {pendingRequests.length === 0
                      ? 'Nothing is waiting for human review.'
                      : `${pendingRequests.length} action${
                          pendingRequests.length === 1
                            ? ''
                            : 's'
                        } waiting for human review.`}
                  </div>
                </div>
              </div>
            </div>

            <div
              className={[
                'rounded-2xl border p-5',
                liveBoundaryReady
                  ? 'border-emerald-300/10 bg-emerald-300/[0.025]'
                  : 'border-amber-300/10 bg-amber-300/[0.025]',
              ].join(' ')}
            >
              <div className="flex items-start gap-3">
                <Fingerprint className="mt-0.5 h-5 w-5 text-zinc-300" />
                <div>
                  <div className="text-sm font-medium text-white">
                    Signing readiness
                  </div>
                  <div className="mt-1 text-xs leading-6 text-zinc-600">
                    {liveBoundaryReady
                      ? 'Live network, protocol, and authorization state are available.'
                      : 'Signing is not considered ready until the live execution boundary is healthy.'}
                  </div>
                </div>
              </div>
            </div>
          </div>
        </Panel>
      </section>

      <section className="grid gap-5 lg:grid-cols-3">
        <Panel
          eyebrow="Intent"
          title="Agent"
        >
          <div className="mt-5 flex items-center justify-between gap-4">
            <div>
              <div className="text-sm font-medium text-white">
                Not claimed by Overview
              </div>
              <div className="mt-1 text-xs leading-6 text-zinc-600">
                Agent identities will appear here once backed by
                authenticated agent state.
              </div>
            </div>

            <ArrowRight className="h-4 w-4 text-zinc-700" />
          </div>
        </Panel>

        <Panel
          eyebrow="Economics"
          title="Money committed"
        >
          <div className="mt-5">
            <div className="text-sm font-medium text-white">
              No verified amount
            </div>
            <div className="mt-1 text-xs leading-6 text-zinc-600">
              Balances, escrow value, and settlement totals are intentionally
              withheld until the corresponding live contract reads or events
              are wired into the state layer.
            </div>
          </div>
        </Panel>

        <Panel
          eyebrow="Verification"
          title="Execution history"
        >
          <div className="mt-5">
            <div className="text-sm font-medium text-white">
              No verified executions
            </div>
            <div className="mt-1 text-xs leading-6 text-zinc-600">
              Activity will populate from verified on-chain execution
              events rather than demo data.
            </div>
          </div>
        </Panel>
      </section>

      <div className="flex flex-wrap items-center gap-x-4 gap-y-2 border-t border-white/6 pt-4 text-xs text-zinc-700">
        <div className="flex items-center gap-2">
          <Globe2 className="h-3.5 w-3.5" />
          Configured chain {akmena.configuredChainId}
        </div>

        <div className="flex items-center gap-2">
          <ShieldCheck className="h-3.5 w-3.5" />
          Core {shortAddress(akmena.coreAddress)}
        </div>

        <div className="flex items-center gap-2">
          <CheckCircle2 className="h-3.5 w-3.5" />
          Data {statusLabel(akmena.dataStatus)}
        </div>
      </div>
    </div>
  );
}
