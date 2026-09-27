import { Panel } from "../../components/ui/Panel";
import { CheckRow } from "../../components/ui/CheckRow";
import { StatusPill } from "../../components/status/StatusPill";

export function SecurityScreen() {
  return (
    <div className="space-y-6">
      <div className="flex flex-col justify-between gap-4 md:flex-row md:items-end">
        <div>
          <div className="text-[10px] font-semibold uppercase tracking-[0.22em] text-cyan-300/70">
            Security Center
          </div>

          <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
            Execution security
          </h1>

          <p className="mt-2 max-w-2xl text-sm leading-6 text-zinc-500">
            The execution boundary is the
            protocol's security surface.
          </p>
        </div>

        <StatusPill
          label="All controls active"
          status="success"
        />
      </div>

      <div className="grid gap-5 xl:grid-cols-[1fr_0.8fr]">
        <Panel
          eyebrow="Control matrix"
          title="Authorization protections"
        >
          <div className="space-y-2">
            <CheckRow
              label="Agent binding"
              detail="Intent is bound to the intended agent."
            />
            <CheckRow
              label="Operator binding"
              detail="Signer context is explicit."
            />
            <CheckRow
              label="Target binding"
              detail="Exact destination contract."
            />
            <CheckRow
              label="Selector binding"
              detail="Exact function selector."
            />
            <CheckRow
              label="Calldata binding"
              detail="Exact transaction payload hash."
            />
            <CheckRow
              label="Economic binding"
              detail="Amount and native value are signed."
            />
            <CheckRow
              label="Proof binding"
              detail="Proof module and proof ID are explicit."
            />
            <CheckRow
              label="Nonce / replay"
              detail="Consumed authorization cannot replay."
            />
            <CheckRow
              label="Validity window"
              detail="Authorization is bounded in time."
            />
          </div>
        </Panel>

        <Panel
          eyebrow="Latest event"
          title="Blocked execution"
        >
          <div className="rounded-xl border border-rose-300/10 bg-rose-300/[0.03] p-5">
            <StatusPill
              label="Execution blocked"
              status="danger"
            />

            <div className="mt-5 space-y-4 text-sm">
              <div className="flex justify-between gap-4">
                <span className="text-zinc-600">
                  Reason
                </span>
                <span className="text-right text-zinc-300">
                  Calldata mismatch
                </span>
              </div>

              <div className="flex justify-between gap-4">
                <span className="text-zinc-600">
                  Funds
                </span>
                <span className="text-emerald-200">
                  Untouched
                </span>
              </div>

              <div className="flex justify-between gap-4">
                <span className="text-zinc-600">
                  Nonce
                </span>
                <span className="text-emerald-200">
                  Unconsumed
                </span>
              </div>

              <div className="flex justify-between gap-4">
                <span className="text-zinc-600">
                  Result
                </span>
                <span className="text-rose-200">
                  Rejected
                </span>
              </div>
            </div>
          </div>

          <div className="mt-5 text-xs leading-5 text-zinc-600">
            The UI will later derive this state
            directly from execution receipts and
            contract events rather than static data.
          </div>
        </Panel>
      </div>
    </div>
  );
}
