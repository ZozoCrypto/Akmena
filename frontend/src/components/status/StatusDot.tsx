type Props = {
  status?: "active" | "success" | "warning" | "danger" | "neutral";
};

const DOTS = {
  active: "bg-cyan-300 shadow-[0_0_12px_rgba(103,232,249,.65)]",
  success: "bg-emerald-300 shadow-[0_0_12px_rgba(110,231,183,.55)]",
  warning: "bg-amber-300 shadow-[0_0_12px_rgba(252,211,77,.45)]",
  danger: "bg-rose-300 shadow-[0_0_12px_rgba(253,164,175,.45)]",
  neutral: "bg-zinc-500",
};

export function StatusDot({
  status = "active",
}: Props) {
  return (
    <span
      aria-hidden="true"
      className={`inline-block h-2 w-2 rounded-full ${DOTS[status]}`}
    />
  );
}
