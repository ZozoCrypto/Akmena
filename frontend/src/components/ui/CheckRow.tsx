type Props = {
  label: string;
  detail?: string;
  status?: "pass" | "pending" | "fail";
};

const STYLES = {
  pass: {
    dot: "bg-emerald-300",
    label: "PASS",
    text: "text-emerald-200",
  },
  pending: {
    dot: "bg-amber-300",
    label: "CHECK",
    text: "text-amber-200",
  },
  fail: {
    dot: "bg-rose-300",
    label: "BLOCKED",
    text: "text-rose-200",
  },
};

export function CheckRow({
  label,
  detail,
  status = "pass",
}: Props) {
  const style = STYLES[status];

  return (
    <div className="flex items-center justify-between gap-4 rounded-xl border border-white/6 bg-white/[0.018] px-4 py-3">
      <div className="min-w-0">
        <div className="text-sm text-zinc-200">
          {label}
        </div>

        {detail && (
          <div className="mt-0.5 truncate text-[11px] text-zinc-600">
            {detail}
          </div>
        )}
      </div>

      <div className="flex shrink-0 items-center gap-2">
        <span
          className={`h-1.5 w-1.5 rounded-full ${style.dot}`}
        />
        <span
          className={`text-[10px] font-semibold tracking-[0.14em] ${style.text}`}
        >
          {style.label}
        </span>
      </div>
    </div>
  );
}
