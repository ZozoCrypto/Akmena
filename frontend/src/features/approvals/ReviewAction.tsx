import { useMemo } from 'react';
import { CheckCircle2, ChevronDown, ShieldCheck } from 'lucide-react';
import type { Address } from 'viem';

import { CheckRow } from '../../components/ui/CheckRow';
import { Panel } from '../../components/ui/Panel';
import { StatusPill } from '../../components/status/StatusPill';

import type {
  ApprovalModel,
  ApprovalSecurityCheck,
} from './approvalTypes';

type Props = {
  approval: ApprovalModel;
  onApprove: () => void | Promise<void>;
  onReject?: () => void;
  approving?: boolean;
};

function shortAddress(address: Address): string {
  return `${address.slice(0, 6)}...${address.slice(-4)}`;
}

function formatAmount(value: bigint): string {
  const whole = value / 10n ** 18n;
  const fraction = value % 10n ** 18n;

  if (fraction === 0n) {
    return whole.toString();
  }

  const fractional = fraction
    .toString()
    .padStart(18, '0')
    .replace(/0+$/, '');

  return `${whole.toString()}.${fractional}`;
}

function formatTimestamp(value: bigint): string {
  return new Date(Number(value) * 1000).toLocaleString(
    undefined,
    {
      dateStyle: 'medium',
      timeStyle: 'short',
    },
  );
}

function checkIsBlocking(
  check: ApprovalSecurityCheck,
): boolean {
  return check.status === 'fail';
}

export function ReviewAction({
  approval,
  onApprove,
  onReject,
  approving = false,
}: Props) {
  const hasBlockingCheck = approval.securityChecks.some(
    checkIsBlocking,
  );

  const passedChecks = approval.securityChecks.filter(
    (check) => check.status === 'pass',
  ).length;

  const totalChecks = approval.securityChecks.length;

  const approvalState = useMemo(() => {
    if (hasBlockingCheck) {
      return {
        label: 'Blocked',
        status: 'danger' as const,
        description:
          'A security boundary does not match this action.',
      };
    }

    if (approving) {
      return {
        label: 'Signing',
        status: 'active' as const,
        description:
          'Waiting for explicit wallet approval.',
      };
    }

    return {
      label: 'Ready',
      status: 'success' as const,
      description:
        'This action has passed the available approval checks.',
    };
  }, [approving, hasBlockingCheck]);

  return (
    <div className="space-y-5">
      <Panel
        eyebrow="Human approval"
        title="Review action"
      >
        <div className="space-y-6">
          <div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
            <div>
              <div className="text-xs font-medium uppercase tracking-[0.18em] text-zinc-600">
                Agent request
              </div>

              <div className="mt-2 text-2xl font-semibold tracking-tight text-white">
                Agent wants to act
              </div>

              <div className="mt-2 text-sm leading-6 text-zinc-500">
                Review exactly what the agent is authorized
                to execute before signing.
              </div>
            </div>

            <StatusPill
              label={approvalState.label}
              status={approvalState.status}
            />
          </div>

          <div className="rounded-2xl border border-cyan-300/10 bg-cyan-300/[0.035] p-5 sm:p-6">
            <div className="text-[10px] font-semibold uppercase tracking-[0.18em] text-cyan-300/65">
              Requested payment
            </div>

            <div className="mt-3 flex flex-wrap items-end gap-x-3 gap-y-1">
              <div className="text-4xl font-semibold tracking-tight text-white">
                {formatAmount(approval.amount)}
              </div>

              <div className="pb-1 text-sm font-medium text-cyan-200">
                signed amount
              </div>
            </div>

            {approval.value > 0n && (
              <div className="mt-2 text-xs text-zinc-500">
                Plus {formatAmount(approval.value)} native value
              </div>
            )}
          </div>

          <div className="grid gap-4 sm:grid-cols-2">
            <div className="rounded-xl border border-white/6 bg-white/[0.018] p-4">
              <div className="text-[10px] uppercase tracking-[0.18em] text-zinc-600">
                Agent
              </div>

              <div className="mt-2 text-sm font-medium text-white">
                Agent
              </div>

              <div className="mt-1 ak-mono text-[11px] text-zinc-500">
                {shortAddress(approval.agent)}
              </div>
            </div>

            <div className="rounded-xl border border-white/6 bg-white/[0.018] p-4">
              <div className="text-[10px] uppercase tracking-[0.18em] text-zinc-600">
                Operator
              </div>

              <div className="mt-2 text-sm font-medium text-white">
                Connected operator
              </div>

              <div className="mt-1 ak-mono text-[11px] text-zinc-500">
                {shortAddress(approval.operator)}
              </div>
            </div>
          </div>

          <div className="rounded-xl border border-white/6 bg-white/[0.018] p-4">
            <div className="text-[10px] uppercase tracking-[0.18em] text-zinc-600">
              Destination
            </div>

            <div className="mt-2 text-sm font-medium text-white">
              Contract target
            </div>

            <div className="mt-1 break-all ak-mono text-[11px] text-zinc-400">
              {approval.target}
            </div>
          </div>

          <div className="grid gap-4 sm:grid-cols-3">
            <div>
              <div className="text-[10px] uppercase tracking-[0.18em] text-zinc-600">
                Network
              </div>
              <div className="mt-2 text-sm text-zinc-200">
                {approval.networkLabel}
              </div>
            </div>

            <div>
              <div className="text-[10px] uppercase tracking-[0.18em] text-zinc-600">
                Nonce
              </div>
              <div className="mt-2 ak-mono text-sm text-zinc-200">
                #{approval.nonce.toString()}
              </div>
            </div>

            <div>
              <div className="text-[10px] uppercase tracking-[0.18em] text-zinc-600">
                Expires
              </div>
              <div className="mt-2 text-sm text-zinc-200">
                {formatTimestamp(approval.deadline)}
              </div>
            </div>
          </div>

          <div className="rounded-xl border border-white/6 bg-black/20 p-4">
            <div className="flex items-center gap-2">
              <ShieldCheck
                size={16}
                className="text-emerald-200"
              />

              <div className="text-sm font-medium text-white">
                Akmena security review
              </div>
            </div>

            <div className="mt-2 text-xs text-zinc-600">
              {passedChecks}/{totalChecks} approval checks currently pass.
            </div>

            <div className="mt-4 space-y-2">
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

          <details className="group rounded-xl border border-white/6 bg-white/[0.018]">
            <summary className="flex cursor-pointer list-none items-center justify-between gap-4 px-4 py-3 text-sm text-zinc-300">
              <span>
                Advanced authorization details
              </span>

              <ChevronDown
                size={16}
                className="text-zinc-600 transition group-open:rotate-180"
              />
            </summary>

            <div className="space-y-4 border-t border-white/6 p-4">
              <div>
                <div className="text-[10px] uppercase tracking-[0.18em] text-zinc-600">
                  Function selector
                </div>
                <div className="mt-1 break-all ak-mono text-[11px] text-zinc-400">
                  {approval.selector}
                </div>
              </div>

              <div>
                <div className="text-[10px] uppercase tracking-[0.18em] text-zinc-600">
                  Calldata hash
                </div>
                <div className="mt-1 break-all ak-mono text-[11px] text-zinc-400">
                  {approval.calldataHash}
                </div>
              </div>

              <div>
                <div className="text-[10px] uppercase tracking-[0.18em] text-zinc-600">
                  Proof module
                </div>
                <div className="mt-1 break-all ak-mono text-[11px] text-zinc-400">
                  {approval.proofModuleKey}
                </div>
              </div>

              <div>
                <div className="text-[10px] uppercase tracking-[0.18em] text-zinc-600">
                  Proof ID
                </div>
                <div className="mt-1 ak-mono text-[11px] text-zinc-400">
                  {approval.proofId.toString()}
                </div>
              </div>

              <div>
                <div className="text-[10px] uppercase tracking-[0.18em] text-zinc-600">
                  EIP-712 verifying contract
                </div>
                <div className="mt-1 break-all ak-mono text-[11px] text-zinc-400">
                  {approval.domain.verifyingContract}
                </div>
              </div>

              <div>
                <div className="text-[10px] uppercase tracking-[0.18em] text-zinc-600">
                  Digest
                </div>
                <div className="mt-1 break-all ak-mono text-[11px] text-zinc-400">
                  {approval.digest}
                </div>
              </div>
            </div>
          </details>

          <div
            className={[
              'rounded-xl border p-4',
              hasBlockingCheck
                ? 'border-rose-300/10 bg-rose-300/[0.03]'
                : 'border-emerald-300/10 bg-emerald-300/[0.025]',
            ].join(' ')}
          >
            <div className="flex items-start gap-3">
              <CheckCircle2
                size={17}
                className={
                  hasBlockingCheck
                    ? 'mt-0.5 text-rose-200'
                    : 'mt-0.5 text-emerald-200'
                }
              />

              <div>
                <div className="text-sm font-medium text-white">
                  {approvalState.description}
                </div>

                <div className="mt-1 text-xs leading-5 text-zinc-600">
                  Signing authorizes exactly this intent. It does not
                  grant a broader permission.
                </div>
              </div>
            </div>
          </div>

          <div className="grid gap-3 sm:grid-cols-2">
            <button
              type="button"
              onClick={onReject}
              disabled={approving}
              className="w-full rounded-xl border border-white/10 bg-white/[0.035] px-4 py-3 text-sm font-semibold text-zinc-300 transition hover:bg-white/[0.06] disabled:cursor-not-allowed disabled:opacity-40"
            >
              Reject
            </button>

            <button
              type="button"
              onClick={() => {
                void onApprove();
              }}
              disabled={hasBlockingCheck || approving}
              className="w-full rounded-xl border border-cyan-300/20 bg-cyan-300/[0.08] px-4 py-3 text-sm font-semibold text-cyan-100 transition hover:bg-cyan-300/[0.13] disabled:cursor-not-allowed disabled:opacity-35"
            >
              {approving ? 'Waiting for wallet...' : 'Approve & sign'}
            </button>
          </div>
        </div>
      </Panel>
    </div>
  );
}
