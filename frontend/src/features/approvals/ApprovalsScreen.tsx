import { useMemo, useState } from 'react';
import {
  ArrowRight,
  Inbox,
  Radio,
  ShieldCheck,
} from 'lucide-react';

import { Panel } from '../../components/ui/Panel';
import { StatusPill } from '../../components/status/StatusPill';
import { useAkmenaState } from '../../state';

import { ReviewAction } from './ReviewAction';
import { useApproveExecutionIntent } from './useApproveExecutionIntent';
import {
  useApprovalRequests,
} from './ApprovalRequestProvider';

function formatRelativeTime(
  timestamp: number,
): string {
  const seconds = Math.max(
    0,
    Math.floor(
      (Date.now() - timestamp) / 1000,
    ),
  );

  if (seconds < 60) {
    return `${seconds}s ago`;
  }

  const minutes = Math.floor(seconds / 60);

  if (minutes < 60) {
    return `${minutes}m ago`;
  }

  const hours = Math.floor(minutes / 60);

  return `${hours}h ago`;
}

function sourceLabel(
  source: 'local' | 'agent' | 'sdk',
): string {
  switch (source) {
    case 'agent':
      return 'Agent';
    case 'sdk':
      return 'SDK';
    default:
      return 'Local';
  }
}

function statusLabel(
  status:
    | 'pending'
    | 'signing'
    | 'signed'
    | 'rejected'
    | 'expired',
): string {
  switch (status) {
    case 'signing':
      return 'Signing';
    case 'signed':
      return 'Signed';
    case 'rejected':
      return 'Rejected';
    case 'expired':
      return 'Expired';
    default:
      return 'Waiting';
  }
}

export function ApprovalsScreen() {
  const akmena = useAkmenaState();

  const {
    requests,
    pendingRequests,
    setRequestSigning,
    setRequestSigned,
    setRequestRejected,
  } = useApprovalRequests();

  const { approveExecutionIntent } =
    useApproveExecutionIntent();

  const [approvalError, setApprovalError] =
    useState<string | null>(null);

  const [selectedId, setSelectedId] =
    useState<string | null>(
      pendingRequests[0]?.id ?? null,
    );

  const selectedRequest = useMemo(() => {
    return requests.find(
      (request) =>
        request.id === selectedId,
    ) ?? null;
  }, [requests, selectedId]);

  const livePendingCount =
    pendingRequests.length;

  return (
    <div className="space-y-6">
      <div className="flex flex-col justify-between gap-4 md:flex-row md:items-end">
        <div>
          <div className="text-[10px] font-semibold uppercase tracking-[0.22em] text-cyan-300/70">
            Approvals
          </div>

          <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
            Review agent actions
          </h1>

          <p className="mt-2 max-w-2xl text-sm leading-6 text-zinc-500">
            Human approval for explicit economic intent.
          </p>
        </div>

        <StatusPill
          label={
            livePendingCount === 0
              ? 'Nothing waiting'
              : `${livePendingCount} waiting`
          }
          status={
            livePendingCount === 0
              ? 'neutral'
              : 'warning'
          }
        />
      </div>

      <div className="rounded-2xl border border-amber-300/10 bg-amber-300/[0.025] p-4">
        <div className="flex items-start gap-3">
          <Radio className="mt-0.5 h-4 w-4 shrink-0 text-amber-200/70" />

          <div>
            <div className="text-sm font-medium text-zinc-200">
              Approval inbox is application state
            </div>

            <div className="mt-1 text-xs leading-5 text-zinc-600">
              This V3 inbox is currently local and in-memory.
              It is not an on-chain queue and does not claim that
              a request originated from a deployed contract.
              Agent and SDK transports will attach here later.
            </div>
          </div>
        </div>
      </div>

      {requests.length === 0 ? (
        <Panel>
          <div className="flex flex-col items-center justify-center px-6 py-14 text-center">
            <div className="flex h-14 w-14 items-center justify-center rounded-2xl border border-white/8 bg-white/[0.025]">
              <Inbox className="h-6 w-6 text-zinc-600" />
            </div>

            <div className="mt-5 text-lg font-semibold text-white">
              No approval requests
            </div>

            <div className="mt-2 max-w-md text-sm leading-6 text-zinc-600">
              When the agent or SDK transport submits an
              explicit execution request, it will appear here
              for human review.
            </div>

            <div className="mt-5 flex items-center gap-2 text-xs text-zinc-700">
              <ShieldCheck className="h-4 w-4" />
              No signing or transaction occurs from an empty inbox.
            </div>
          </div>
        </Panel>
      ) : (
        <div className="grid gap-5 xl:grid-cols-[0.72fr_1.28fr]">
          <Panel
            eyebrow="Inbox"
            title="Pending requests"
          >
            <div className="space-y-2">
              {requests.map((request) => {
                const selected =
                  request.id === selectedId;

                return (
                  <button
                    key={request.id}
                    type="button"
                    onClick={() =>
                      setSelectedId(request.id)
                    }
                    className={[
                      'w-full rounded-xl border px-4 py-4 text-left transition',
                      selected
                        ? 'border-cyan-300/20 bg-cyan-300/[0.055]'
                        : 'border-white/6 bg-white/[0.018] hover:bg-white/[0.035]',
                    ].join(' ')}
                  >
                    <div className="flex items-start justify-between gap-3">
                      <div className="min-w-0">
                        <div className="truncate text-sm font-medium text-white">
                          {request.title}
                        </div>

                        <div className="mt-1 text-xs text-zinc-600">
                          {sourceLabel(request.source)}
                          {' · '}
                          {formatRelativeTime(
                            request.createdAt,
                          )}
                        </div>
                      </div>

                      <StatusPill
                        label={statusLabel(
                          request.status,
                        )}
                        status={
                          request.status === 'pending'
                            ? 'warning'
                            : request.status === 'signing'
                              ? 'active'
                              : request.status === 'signed'
                                ? 'success'
                                : request.status === 'expired'
                                  ? 'danger'
                                  : 'neutral'
                        }
                      />
                    </div>

                    <div className="mt-3 flex items-center justify-between">
                      <span className="ak-mono text-[11px] text-zinc-600">
                        {request.approval.target}
                      </span>

                      <ArrowRight
                        className={[
                          'h-4 w-4',
                          selected
                            ? 'text-cyan-200/70'
                            : 'text-zinc-700',
                        ].join(' ')}
                      />
                    </div>
                  </button>
                );
              })}
            </div>
          </Panel>

          <div>
            {selectedRequest ? (
              <ReviewAction
                approval={selectedRequest.approval}
                approving={
                  selectedRequest.status === 'signing'
                }
                onApprove={async () => {

                  setApprovalError(null);

                  setRequestSigning(

                    selectedRequest.id,

                  );


                  try {

                    const signature =

                      await approveExecutionIntent(

                        selectedRequest.approval,

                      );


                    setRequestSigned(

                      selectedRequest.id,

                      signature,

                    );

                  } catch (error) {

                    setRequestStatus(

                      selectedRequest.id,

                      'pending',

                    );


                    setApprovalError(

                      error instanceof Error

                        ? error.message

                        : 'Wallet signing failed.',

                    );

                  }

                }}
                onReject={() => {
                  setApprovalError(null);
                  setRequestRejected(
                    selectedRequest.id,
                  );
                }}
              />
            ) : (
              <Panel>
                <div className="p-6 text-sm text-zinc-600">
                  Select an approval request to review it.
                </div>
              </Panel>
            )}

            {approvalError && (
              <div className="mt-3 rounded-xl border border-red-300/10 bg-red-300/[0.035] px-4 py-3 text-sm leading-6 text-red-200/90">
                {approvalError}
              </div>
            )}

            <div className="mt-3 text-xs text-zinc-700">
              Protocol network:{' '}
              {akmena.configuredChainId}
              {' · '}
              Protocol:{' '}
              {akmena.protocolStatus}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
