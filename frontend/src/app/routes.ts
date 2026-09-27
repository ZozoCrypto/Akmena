export type AppRoute =
  | "overview"
  | "agents" |
  "approvals" | "execution"
  | "payments"
  | "security"
  | "activity";

export const APP_ROUTES: Array<{
  id: AppRoute;
  label: string;
  description: string;
}> = [
  {
    id: "overview",
    label: "Overview",
    description:
      "Protocol health and economic execution.",
  },
  {
    id: "agents",
    label: "Agents",
    description:
      "Identity, authorization, and spending policy.",
  },
  {
    id: "approvals",
    label: "Approvals",
    description: "Review pending agent actions.",
  },
  {
    id: "execution",
    label: "Execution",
    description:
      "Intent, authorization, verification, and execution.",
  },
  {
    id: "payments",
    label: "Payments",
    description:
      "AKM, escrow, and settlement activity.",
  },
  {
    id: "security",
    label: "Security",
    description:
      "Execution-boundary controls and verification.",
  },
  {
    id: "activity",
    label: "Activity",
    description:
      "Auditable economic execution history.",
  },
];
