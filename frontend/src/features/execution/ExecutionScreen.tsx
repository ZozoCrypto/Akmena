import { useState } from "react";

import { CheckRow } from "../../components/ui/CheckRow";
import { Panel } from "../../components/ui/Panel";
import { StatusPill } from "../../components/status/StatusPill";

import {
  useExecutionIntent,
} from "./useExecutionIntent";

import { ApprovalReview } from "../approvals/ApprovalReview";
import { createApprovalModel } from "../approvals/approvalTypes";
import { useAkmenaState } from "../../state";

const CHECKS = [
  "Agent binding",
  "Operator binding",
  "Exact target",
  "Exact selector",
  "Exact calldata",
  "Exact amount",
  "Exact native value",
  "Proof binding",
  "Nonce / replay",
  "Validity window",
];

export function ExecutionScreen() {
  const akmena = useAkmenaState();
  const [target, setTarget] = useState("");
  const [selector, setSelector] = useState("0x00000000");
  const [calldata, setCalldata] = useState("");
  const [amount, setAmount] = useState("1.00");
  const [value, setValue] = useState("0");

  const {
    intent,
    domain,
    authorization,
    digest,
    signature,
    recoveredSigner,
    error,
    loading,
    build,
    sign,
  } = useExecutionIntent();

  const ready =
    Boolean(target) &&
    Boolean(selector) &&
    Boolean(calldata) &&
    Number(amount) > 0 &&
    Number(value) >= 0;

  const signed =
    Boolean(signature) &&
    Boolean(recoveredSigner);

  const approval =
    intent &&
    domain &&
    digest &&
    authorization
      ? createApprovalModel(
          intent,
          domain,
          digest,
          akmena.configuredChainId,
          authorization,
        )
      : null;

  const approvalBlocked =
    approval?.securityChecks.some(
      (check) => check.status === 'fail',
    ) ?? false;

  async function handleBuild() {
    await build({
      agent: "0xC72CBbeaf7F540522804BcbF592dc7a6b6906476",
      target,
      selector,
      calldata,
      amount,
      value,
    });
  }

  async function handleSign() {
    await sign();
  }

  return (
    <div className="space-y-6">
      <div>
        <div className="text-[10px] font-semibold uppercase tracking-[0.22em] text-cyan-300/70">
          Execution
        </div>

        <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
          Review an agent action
        </h1>

        <p className="mt-2 max-w-2xl text-sm leading-6 text-zinc-500">
          Review the exact action your agent is asking you to authorize.
        </p>
      </div>

      <div className="grid gap-5 xl:grid-cols-[1.05fr_0.95fr]">
        <Panel
          eyebrow="Intent"
          title="Execution parameters"
        >
          <div className="space-y-5">
            <div>
              <label className="mb-2 block text-[10px] font-semibold uppercase tracking-[0.18em] text-zinc-600">
                Agent
              </label>

              <div className="ak-panel-subtle rounded-xl px-4 py-3 text-sm text-zinc-300">
                Agent-007
              </div>
            </div>

            <div>
              <label className="mb-2 block text-[10px] font-semibold uppercase tracking-[0.18em] text-zinc-600">
                Target contract
              </label>

              <input
                value={target}
                onChange={(event) => setTarget(event.target.value)}
                placeholder="0x..."
                className="w-full rounded-xl border border-white/8 bg-black/20 px-4 py-3 text-sm text-zinc-200 outline-none transition placeholder:text-zinc-700 focus:border-cyan-300/30"
              />
            </div>

            <div>
              <label className="mb-2 block text-[10px] font-semibold uppercase tracking-[0.18em] text-zinc-600">
                Selector
              </label>

              <input
                value={selector}
                onChange={(event) => setSelector(event.target.value)}
                placeholder="0x00000000"
                className="ak-mono w-full rounded-xl border border-white/8 bg-black/20 px-4 py-3 text-xs text-zinc-200 outline-none transition placeholder:text-zinc-700 focus:border-cyan-300/30"
              />
            </div>

            <div>
              <label className="mb-2 block text-[10px] font-semibold uppercase tracking-[0.18em] text-zinc-600">
                Action
              </label>

              <div className="ak-panel-subtle rounded-xl px-4 py-3 text-sm text-zinc-300">
                Execute authorized call
              </div>
            </div>

            <div>
              <label className="mb-2 block text-[10px] font-semibold uppercase tracking-[0.18em] text-zinc-600">
                Calldata
              </label>

              <textarea
                value={calldata}
                onChange={(event) => setCalldata(event.target.value)}
                placeholder="0x..."
                rows={5}
                className="ak-mono w-full rounded-xl border border-white/8 bg-black/20 px-4 py-3 text-xs text-zinc-200 outline-none transition placeholder:text-zinc-700 focus:border-cyan-300/30"
              />
            </div>

            <div className="grid gap-4 sm:grid-cols-2">
              <div>
                <label className="mb-2 block text-[10px] font-semibold uppercase tracking-[0.18em] text-zinc-600">
                  Amount
                </label>

                <input
                  value={amount}
                  onChange={(event) => setAmount(event.target.value)}
                  inputMode="decimal"
                  className="w-full rounded-xl border border-white/8 bg-black/20 px-4 py-3 text-sm text-zinc-200 outline-none focus:border-cyan-300/30"
                />
              </div>

              <div>
                <label className="mb-2 block text-[10px] font-semibold uppercase tracking-[0.18em] text-zinc-600">
                  Native value
                </label>

                <input
                  value={value}
                  onChange={(event) => setValue(event.target.value)}
                  inputMode="decimal"
                  className="w-full rounded-xl border border-white/8 bg-black/20 px-4 py-3 text-sm text-zinc-200 outline-none focus:border-cyan-300/30"
                />
              </div>
            </div>

            <div>
              <label className="mb-2 block text-[10px] font-semibold uppercase tracking-[0.18em] text-zinc-600">
                Nonce
              </label>

              <div className="ak-panel-subtle ak-mono rounded-xl px-4 py-3 text-sm text-zinc-300">
                {intent ? intent.nonce.toString() : "Assigned during verification"}
              </div>
            </div>

            <div className="rounded-xl border border-cyan-300/10 bg-cyan-300/[0.035] p-4">
              <div className="flex items-center justify-between gap-4">
                <div>
                  <div className="text-sm font-medium text-white">
                    {signed
                      ? "Execution intent signed"
                      : intent
                        ? "Intent verified"
                        : "Ready for verification"}
                  </div>

                  <div className="mt-1 text-xs leading-5 text-zinc-600">
                    {signed
                      ? "The wallet signature was recovered locally and bound to the connected operator."
                      : intent
                        ? "The intent is ready for explicit wallet signing."
                        : "No blockchain transaction is sent from this screen."}
                  </div>
                </div>

                <StatusPill
                  label={
                    signed
                      ? "Signed"
                      : intent
                        ? "Verified"
                        : ready
                          ? "Intent ready"
                          : "Awaiting input"
                  }
                  status={
                    signed
                      ? "success"
                      : intent
                        ? "success"
                        : ready
                          ? "success"
                          : "warning"
                  }
                />
              </div>
            </div>

            {error && (
              <div className="rounded-xl border border-rose-300/10 bg-rose-300/[0.035] p-4">
                <div className="text-[10px] font-semibold uppercase tracking-[0.18em] text-rose-300/70">
                  Security error
                </div>

                <div className="mt-2 break-words text-xs leading-5 text-rose-200/80">
                  {error}
                </div>
              </div>
            )}

            <div className="grid gap-3 sm:grid-cols-2">
              <button
                type="button"
                disabled={!ready || loading}
                onClick={() => {
                  void handleBuild();
                }}
                className="w-full rounded-xl border border-cyan-300/20 bg-cyan-300/[0.08] px-4 py-3 text-sm font-semibold text-cyan-100 transition hover:bg-cyan-300/[0.12] disabled:cursor-not-allowed disabled:opacity-35"
              >
                {loading ? "Verifying..." : "Review execution"}
              </button>

              <button
                type="button"
                disabled={!intent || loading || approvalBlocked}
                onClick={() => {
                  void handleSign();
                }}
                className="w-full rounded-xl border border-white/10 bg-white/[0.04] px-4 py-3 text-sm font-semibold text-white transition hover:bg-white/[0.07] disabled:cursor-not-allowed disabled:opacity-35"
              >
                {signed ? "Intent signed" : "Sign exact intent"}
              </button>
            </div>
          </div>
        </Panel>

        {approval && (
          <ApprovalReview
            approval={approval}
            approving={loading}
            onApprove={async () => {
              await handleSign();
            }}
          />
        )}

        {approval && !approvalBlocked && !signed && (
          <div className="text-xs text-zinc-600">
            The approval above is derived directly from the
            signed execution intent and the live Authorization
            boundary.
          </div>
        )}

        <Panel
          eyebrow="Security"
          title="Execution boundary"
        >
          <div className="space-y-2">
            {CHECKS.map((check) => (
              <CheckRow
                key={check}
                label={check}
                status={
                  intent
                    ? "pass"
                    : ready
                      ? "pass"
                      : "pending"
                }
              />
            ))}
          </div>

          <div className="mt-5 rounded-xl border border-white/6 bg-black/20 p-4">
            <div className="text-[10px] uppercase tracking-[0.18em] text-zinc-600">
              EIP-712 domain
            </div>

            <div className="mt-2 space-y-1 text-xs text-zinc-500">
              <div>
                Name:{" "}
                <span className="ak-mono text-zinc-300">
                  {domain?.name ?? "—"}
                </span>
              </div>

              <div>
                Version:{" "}
                <span className="ak-mono text-zinc-300">
                  {domain?.version ?? "—"}
                </span>
              </div>

              <div>
                Chain:{" "}
                <span className="ak-mono text-zinc-300">
                  {domain?.chainId.toString() ?? "—"}
                </span>
              </div>

              <div>
                Verifying:{" "}
                <span className="ak-mono break-all text-zinc-300">
                  {domain?.verifyingContract ?? "—"}
                </span>
              </div>
            </div>
          </div>

          <div className="mt-4 rounded-xl border border-white/6 bg-black/20 p-4">
            <div className="text-[10px] uppercase tracking-[0.18em] text-zinc-600">
              Authorization
            </div>

            <div className="mt-2 ak-mono break-all text-[11px] leading-5 text-zinc-400">
              {authorization ?? "—"}
            </div>
          </div>

          <div className="mt-4 rounded-xl border border-cyan-300/10 bg-cyan-300/[0.025] p-4">
            <div className="text-[10px] uppercase tracking-[0.18em] text-zinc-600">
              EIP-712 digest
            </div>

            <div className="mt-2 ak-mono break-all text-[11px] leading-5 text-zinc-400">
              {digest ?? "Build an intent to compute the digest."}
            </div>
          </div>

          <div className="mt-4 rounded-xl border border-white/6 bg-black/20 p-4">
            <div className="text-[10px] uppercase tracking-[0.18em] text-zinc-600">
              Recovered signer
            </div>

            <div className="mt-2 ak-mono break-all text-[11px] leading-5 text-zinc-400">
              {recoveredSigner ?? "—"}
            </div>
          </div>

          <div className="mt-4 rounded-xl border border-white/6 bg-black/20 p-4">
            <div className="text-[10px] uppercase tracking-[0.18em] text-zinc-600">
              Signature
            </div>

            <div className="mt-2 ak-mono break-all text-[11px] leading-5 text-zinc-400">
              {signature ?? "No wallet signature requested."}
            </div>
          </div>
        </Panel>
      </div>
    </div>
  );
}
