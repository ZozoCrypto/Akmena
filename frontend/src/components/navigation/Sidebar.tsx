import type { AppRoute } from "../../app/routes";
import { APP_ROUTES } from "../../app/routes";
import { StatusPill } from "../status/StatusPill";

type Props = {
  activeRoute: AppRoute;
  onNavigate: (route: AppRoute) => void;
};

const ICONS: Record<AppRoute, string> = {
  overview: "⌂",
  agents: "◈",
  execution: "↗",
  payments: "◇",
  security: "⬢",
  activity: "≡",
};

export function Sidebar({
  activeRoute,
  onNavigate,
}: Props) {
  return (
    <aside className="sticky top-0 hidden h-screen w-72 shrink-0 border-r border-white/8 bg-black/20 lg:flex lg:flex-col">
      <div className="px-6 pb-5 pt-7">
        <div className="flex items-center gap-3">
          <div className="flex h-10 w-10 items-center justify-center rounded-xl border border-cyan-300/20 bg-cyan-300/[0.06] text-sm font-semibold text-cyan-200">
            A
          </div>

          <div>
            <div className="text-sm font-semibold tracking-[0.18em] text-white">
              AKMENA
            </div>
            <div className="mt-0.5 text-[10px] uppercase tracking-[0.22em] text-zinc-500">
              Economic Infrastructure
            </div>
          </div>
        </div>
      </div>

      <nav className="flex-1 px-3">
        <div className="mb-3 px-3 text-[10px] font-semibold uppercase tracking-[0.22em] text-zinc-600">
          Protocol
        </div>

        <div className="space-y-1">
          {APP_ROUTES.map((route) => {
            const active =
              activeRoute === route.id;

            return (
              <button
                key={route.id}
                type="button"
                onClick={() =>
                  onNavigate(route.id)
                }
                className={[
                  "group flex w-full items-start gap-3 rounded-xl px-3 py-3 text-left transition",
                  active
                    ? "border border-white/8 bg-white/[0.055] text-white"
                    : "text-zinc-500 hover:bg-white/[0.03] hover:text-zinc-200",
                ].join(" ")}
              >
                <span
                  className={[
                    "mt-0.5 flex h-7 w-7 items-center justify-center rounded-lg text-sm",
                    active
                      ? "bg-cyan-300/[0.08] text-cyan-200"
                      : "bg-white/[0.025] text-zinc-500",
                  ].join(" ")}
                >
                  {ICONS[route.id]}
                </span>

                <span className="min-w-0">
                  <span className="block text-sm font-medium">
                    {route.label}
                  </span>
                  <span className="mt-0.5 block truncate text-[11px] text-zinc-600 group-hover:text-zinc-500">
                    {route.description}
                  </span>
                </span>
              </button>
            );
          })}
        </div>
      </nav>

      <div className="space-y-3 border-t border-white/8 p-5">
        <StatusPill
          label="Base Sepolia"
          status="success"
        />

        <div className="text-[11px] leading-5 text-zinc-600">
          Autonomous economic execution,
          bounded by cryptographic intent.
        </div>
      </div>
    </aside>
  );
}
