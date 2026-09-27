import { Panel } from "../../components/ui/Panel";

const EVENTS = [
  {
    time: "12:41:03",
    title: "Execution authorized",
    detail: "Agent-007 · 1.00 USDC",
    status: "AUTHORIZED",
  },
  {
    time: "12:41:08",
    title: "Execution verified",
    detail: "Nonce #184 · exact target",
    status: "VERIFIED",
  },
  {
    time: "12:41:09",
    title: "Base execution confirmed",
    detail: "Settlement completed",
    status: "CONFIRMED",
  },
  {
    time: "12:42:11",
    title: "Attack blocked",
    detail: "Calldata hash mismatch",
    status: "BLOCKED",
  },
];

export function ActivityScreen() {
  return (
    <div className="space-y-6">
      <div>
        <div className="text-[10px] font-semibold uppercase tracking-[0.22em] text-cyan-300/70">
          Activity
        </div>
        <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
          Economic audit trail
        </h1>
        <p className="mt-2 text-sm leading-6 text-zinc-500">
          A readable record of authorization,
          verification, execution, and rejection.
        </p>
      </div>

      <Panel
        eyebrow="Timeline"
        title="Recent protocol events"
      >
        <div className="space-y-1">
          {EVENTS.map((event) => (
            <div
              key={`${event.time}-${event.title}`}
              className="grid gap-3 rounded-xl border border-transparent px-3 py-4 transition hover:border-white/6 hover:bg-white/[0.018] md:grid-cols-[90px_1fr_auto]"
            >
              <div className="ak-mono text-[11px] text-zinc-700">
                {event.time}
              </div>

              <div>
                <div className="text-sm text-zinc-200">
                  {event.title}
                </div>
                <div className="mt-1 text-xs text-zinc-600">
                  {event.detail}
                </div>
              </div>

              <div
                className={[
                  "text-[10px] font-semibold tracking-[0.15em]",
                  event.status ===
                  "BLOCKED"
                    ? "text-rose-200"
                    : "text-emerald-200",
                ].join(" ")}
              >
                {event.status}
              </div>
            </div>
          ))}
        </div>
      </Panel>
    </div>
  );
}
