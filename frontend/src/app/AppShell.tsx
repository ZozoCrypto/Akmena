import type { ReactNode } from "react";

import type { AppRoute } from "./routes";
import { Sidebar } from "../components/navigation/Sidebar";
import { TopBar } from "../components/navigation/TopBar";
import { MobileNav } from "../components/navigation/MobileNav";

type Props = {
  activeRoute: AppRoute;
  onNavigate: (route: AppRoute) => void;
  wallet?: `0x${string}`;
  chainId?: number;
  children: ReactNode;
};

export function AppShell({
  activeRoute,
  onNavigate,
  wallet,
  chainId,
  children,
}: Props) {
  return (
    <div className="ak-shell ak-grid-bg">
      <div className="flex min-h-screen">
        <Sidebar
          activeRoute={activeRoute}
          onNavigate={onNavigate}
        />

        <div className="min-w-0 flex-1">
          <TopBar
            wallet={wallet}
            chainId={chainId}
          />

          <MobileNav
            activeRoute={activeRoute}
            onNavigate={onNavigate}
          />

          <main className="mx-auto max-w-[1600px] p-4 sm:p-6 xl:p-8">
            {children}
          </main>
        </div>
      </div>
    </div>
  );
}
