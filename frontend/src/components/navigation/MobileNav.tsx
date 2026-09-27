import type { AppRoute } from "../../app/routes";
import { APP_ROUTES } from "../../app/routes";

type Props = {
  activeRoute: AppRoute;
  onNavigate: (route: AppRoute) => void;
};

export function MobileNav({
  activeRoute,
  onNavigate,
}: Props) {
  return (
    <div className="overflow-x-auto border-b border-white/8 lg:hidden">
      <div className="flex min-w-max gap-1 px-4 py-2">
        {APP_ROUTES.map((route) => (
          <button
            key={route.id}
            type="button"
            onClick={() =>
              onNavigate(route.id)
            }
            className={[
              "rounded-lg px-3 py-2 text-xs font-medium transition",
              activeRoute === route.id
                ? "bg-white/[0.06] text-white"
                : "text-zinc-600 hover:text-zinc-300",
            ].join(" ")}
          >
            {route.label}
          </button>
        ))}
      </div>
    </div>
  );
}
