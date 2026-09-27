import { Panel } from "../../components/ui/Panel";
import { StatusPill } from "../../components/status/StatusPill";

export function AgentsScreen() {
  return (
    <div className="space-y-6">
      <div>
        <div className="text-[10px] font-semibold uppercase tracking-[0.22em] text-cyan-300/70">
          Agent Control
        </div>
        <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
          Agents
        </h1>
        <p className="mt-2 max-w-2xl text-sm leading-6 text-zinc-500">
          Manage agent identity,
          authorization, and spending policy.
        </p>
      </div>

      <Panel
        eyebrow="Connected agent"
        title="Agent-007"
      >
        <div className="grid gap-5 md:grid-cols-2 xl:grid-cols-4">
          <div>
            <div className="text-[10px] uppercase tracking-[0.18em] text-zinc-600">
              Identity
            </div>
            <div className="mt-2 break-all text-xs text-zinc-300 ak-mono">
              0xC72C...6476
            </div>
          </div>

          <div>
            <div className="text-[10px] uppercase tracking-[0.18em] text-zinc-600">
              Authorization
            </div>
            <div className="mt-2">
              <StatusPill
                label="Active"
                status="success"
              />
            </div>
          </div>

          <div>
            <div className="text-[10px] uppercase tracking-[0.18em] text-zinc-600">
              Per Transaction
            </div>
            <div className="mt-2 text-sm text-white">
              10 USDC
            </div>
          </div>

          <div>
            <div className="text-[10px] uppercase tracking-[0.18em] text-zinc-600">
              Daily Limit
            </div>
            <div className="mt-2 text-sm text-white">
              100 USDC
            </div>
          </div>
        </div>
      </Panel>

      <div className="grid gap-5 lg:grid-cols-2">
        <Panel
          eyebrow="Identity"
          title="Agent identity"
        >
          <div className="space-y-3 text-sm">
            <div className="flex justify-between border-b border-white/6 pb-3">
              <span className="text-zinc-600">
                Wallet
              </span>
              <span className="ak-mono text-zinc-300">
                0xC72C...6476
              </span>
            </div>

            <div className="flex justify-between border-b border-white/6 pb-3">
              <span className="text-zinc-600">
                Network
              </span>
              <span className="text-zinc-300">
                Base Sepolia
              </span>
            </div>

            <div className="flex justify-between">
              <span className="text-zinc-600">
                Status
              </span>
              <span className="text-emerald-200">
                Operational
              </span>
            </div>
          </div>
        </Panel>

        <Panel
          eyebrow="Spending policy"
          title="Economic guardrails"
        >
          <div className="space-y-3 text-sm">
            <div className="flex justify-between border-b border-white/6 pb-3">
              <span className="text-zinc-600">
                Maximum per transaction
              </span>
              <span className="text-zinc-300">
                10 USDC
              </span>
            </div>

            <div className="flex justify-between border-b border-white/6 pb-3">
              <span className="text-zinc-600">
                Daily maximum
              </span>
              <span className="text-zinc-300">
                100 USDC
              </span>
            </div>

            <div className="flex justify-between">
              <span className="text-zinc-600">
                Proof required
              </span>
              <span className="text-emerald-200">
                Yes
              </span>
            </div>
          </div>
        </Panel>
      </div>
    </div>
  );
}
