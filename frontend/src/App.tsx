import { useState } from "react";

import {
  useAccount,
} from "wagmi";

import type {
  AppRoute,
} from "./app/routes";

import { AppShell } from "./app/AppShell";

import {
  OverviewScreen,
} from "./features/overview/OverviewScreen";

import {
  AgentsScreen,
} from "./features/agents/AgentsScreen";

import {
  ExecutionScreen,
} from "./features/execution/ExecutionScreen";

import {
  PaymentsScreen,
} from "./features/payments/PaymentsScreen";

import {
  SecurityScreen,
} from "./features/security/SecurityScreen";

import {
  ActivityScreen,
} from "./features/activity/ActivityScreen";

import {
  ApprovalsScreen,
} from "./features/approvals/ApprovalsScreen";

export default function App() {
  const {
    address,
    chainId,
  } = useAccount();

  const [activeRoute, setActiveRoute] =
    useState<AppRoute>("overview");

  function renderScreen() {
    switch (activeRoute) {
      case "agents":
        return <AgentsScreen />;

      case "approvals":
        return <ApprovalsScreen />;

      case "execution":
        return <ExecutionScreen />;

      case "payments":
        return <PaymentsScreen />;

      case "security":
        return <SecurityScreen />;

      case "activity":
        return <ActivityScreen />;

      case "overview":
      default:
        return <OverviewScreen />;
    }
  }

  return (
    <AppShell
      activeRoute={activeRoute}
      onNavigate={setActiveRoute}
      wallet={address}
      chainId={chainId}
    >
      {renderScreen()}
    </AppShell>
  );
}
