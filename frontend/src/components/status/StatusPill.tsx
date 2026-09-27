import { StatusDot } from "./StatusDot";

type Props = {
  label: string;
  status?: "active" | "success" | "warning" | "danger" | "neutral";
};

export function StatusPill({
  label,
  status = "active",
}: Props) {
  return (
    <span className="inline-flex items-center gap-2 rounded-full border border-white/10 bg-white/[0.035] px-3 py-1.5 text-xs font-medium text-zinc-200">
      <StatusDot status={status} />
      {label}
    </span>
  );
}
