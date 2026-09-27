import { useMemo } from 'react';
import { ShieldCheck, ChevronDown } from 'lucide-react';

import { Panel } from '../../components/ui/Panel';
import { CheckRow } from '../../components/ui/CheckRow';
import { StatusPill } from '../../components/status/StatusPill';

import type { ApprovalModel } from './approvalTypes';

type Props = {
  approval: ApprovalModel;
  onApprove: () => void | Promise<void>;
  approving?: boolean;
};

function shortAddress(address: string): string {
  return `${address.slice(0, 6)}...${address.slice(-4)}`;
}

function formatUnits(value: bigint): string {
  const whole = value / 1_000_000_000_000_000_000n;
  const fraction =
    value % 1_000_000_000_000_000_000n;

  if (fraction === 0n) {
    return whole.toString();
  }

  return `${whole}.${fraction
    .toString()
    .padStart(18, '0')
    .replace(/0+$/, '')}`;
}

function formatTimestamp(value: bigint): string {
  const milliseconds = Number(value) * 1000;

  if (!Number.isFinite(milliseconds)) {
    return 'Unknown';
  }

  return new Date(milliseconds).toLocaleString();
}

export function ApprovalReview({
  approval,
  onApprove,
  approving = false,
}: Props) {
  const failedChecks = useMemo(
    () =>
      approval.securityChecks.filter(
        (check) => check.status === 'fail',
      ),
    [approval.securityChecks],
  );

  const blocked = failedChecks.length > 0;

  return (
    <div className="space-y-5">
      <Panel
        eyebrow="Review action"
        title="Your agent is requesting approval"
      >
        <div className="space-y-6">
          <div className="rounded-2xl border border-cyan-300/10 bg-cyan-300/[0.035] p-5">
            <div className="flex flex-col gap-5 sm:flex-row sm:items-center sm:justify-between">
              <div>
                <div className="text-[10px] font-semibold uppercase tracking-[0.2em] text-zinc-600">
                  Requested by
                </div>

                <div className="mt-2 text-lg font-semibold text-white">
                  Agent
                </div>

                <div className="mt-1 ak-mono text-xs text-zinc-500">
                  {shortAddress(approval.agent)}
                </div>
              </div>

              <div className="sm:text-right">
                <div className="text-[10px] font-semibold uppercase tracking-[0.2em] text-zinc-600">
                  Signed amount
                </div>

                <div className="mt-2 text-3xl font-semibold tracking-tight text-white">
                  {formatUnits(approval.amount)}
                </div>

                {approval.value > 0n && (
                  <div className="mt-1 text-xs text-zinc-500">
                    + {formatUnits(approval.value)} native value
                  </div>
                )}
              </div>
            </div>
          </div>

          <div className="grid gap-4 sm:grid-cols-2">
            <div className="ak-panel-subtle rounded-xl p-4">
              <div className="text-[10px] uppercase tracking-[0.18em] text-zinc-600">
                Recipient / target
              </div>

              <div className="mt-2 ak-mono break-all text-xs text-zinc-300">
                {approval.target}
              </div>
            </div>

            <div className="ak-panel-subtle rounded-xl p-4">
              <div className="text-[10px] uppercase tracking-[0.18em] text-zinc-600">
                Network
              </div>

              <div className="mt-2 text-sm font-medium text-white">
                {approval.networkLabel}
              </div>

              <div className="mt-1 text-xs text-zinc-600">
                Chain {approval.domain.chainId.toString()}
              </div>
            </div>

            <div className="ak-panel-subtle rounded-xl p-4">
              <div className="text-[10px] uppercase tracking-[0.18em] text-zinc-600">
                Nonce
              </div>

              <div className="mt-2 ak-mono text-sm text-zinc-300">
                #{approval.nonce.toString()}
              </div>
            </div>

            <div className="ak-panel-subtle rounded-xl p-4">
              <div className="text-[10px] uppercase tracking-[0.18em] text-zinc-600">
                Expires
              </div>

              <div className="mt-2 text-sm text-zinc-300">
                {formatTimestamp(approval.deadline)}
              </div>
            </div>
          </div>

          <div>
            <div className="mb-3 flex items-center justify-between">
              <div>
                <div className="text-[10px] font-semibold uppercase tracking-[0.2em] text-zinc-600">
                  Protection
                </div>
                <div className="mt-1 text-sm font-medium text-white">
                  What Akmena verifies before execution
                </div>
              </div>

              <StatusPill
                label={
                  blocked
                    ? `${failedChecks.length} blocked`
                    : 'Protected'
                }
                status={blocked ? 'danger' : 'success'}
              />
            </div>

            <div className="space-y-2">
              {approval.securityChecks.map((check) => (
                <CheckRow
                  key={check.id}
                  label={check.label}
                  detail={check.detail}
                  status={
                    check.status === 'fail'
                      ? 'fail'
                      : check.status === 'pending'
                        ? 'pending'
                        : 'pass'
                  }
                />
              ))}
            </div>
          </div>

          <details className="group rounded-xl border border-white/6 bg-black/20">
            <summary className="flex cursor-pointer list-none items-center justify-between px-4 py-3 text-sm text-zinc-300">
              <span className="flex items-center gap-2">
                <ShieldCheck className="h-4 w-4 text-cyan-200/70" />
                Advanced cryptographic details
              </span>

              <ChevronDown className="h-4 w-4 text-zinc-600 transition-transform group-open:rotate-180" />
            </summary>

            <div className="space-y-4 border-t border-white/6 p-4">
              <div>
                <div className="text-[10px] uppercase tracking-[0.18em] text-zinc-600">
                  Operator
                </div>
                <div className="mt-1 ak-mono break-all text-[11px] text-zinc-400">
                  {approval.operator}
                </div>
              </div>

              <div>
                <div className="text-[10px] uppercase tracking-[0.18em] text-zinc-600">
                  Function selector
                </div>
                <div className="mt-1 ak-mono text-[11px] text-zinc-400">
                  {approval.selector}
                </div>
              </div>

              <div>
                <div className="text-[10px] uppercase tracking-[0.18em] text-zinc-600">
                  Calldata hash
                </div>
                <div className="mt-1 ak-mono break-all text-[11px] text-zinc-400">
                  {approval.calldataHash}
                </div>
              </div>

              <div>
                <div className="text-[10px] uppercase tracking-[0.18em] text-zinc-600">
                  Proof
                </div>
                <div className="mt-1 ak-mono break-all text-[11px] text-zinc-400">
                  {approval.proofModuleKey} / #
                  {approval.proofId.toString()}
                </div>
              </div>

              <div>
                <div className="text-[10px] uppercase tracking-[0.18em] text-zinc-600">
                  EIP-712 verifying contract
                </div>
                <div className="mt-1 ak-mono break-all text-[11px] text-zinc-400">
                  {approval.domain.verifyingContract}
                </div>
              </div>

              <div>
                <div className="text-[10px] uppercase tracking-[0.18em] text-zinc-600">
                  Digest
                </div>
                <div className="mt-1 ak-mono break-all text-[11px] text-zinc-400">
                  {approval.digest}
                </div>
              </div>
            </div>
          </details>

          <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
            <div className="text-xs leading-5 text-zinc-600">
              Approving signs the exact EIP-712 execution intent.
              It does not authorize anything broader.
            </div>

            <button
              type="button"
              disabled={blocked || approving}
              onClick={() => {
                void onApprove();
              }}
              className="rounded-xl border border-cyan-300/20 bg-cyan-300/[0.10] px-5 py-3 text-sm font-semibold text-cyan-100 transition hover:bg-cyan-300/[0.15] disabled:cursor-not-allowed disabled:opacity-35"
            >
              {approving ? 'Signing...' : 'Approve action'}
            </button>
          </div>
        </div>
      </Panel>
    </div>
  );
}
