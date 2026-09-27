type Props = {
  label: string;
  value: string;
  detail?: string;
};

export function Metric({
  label,
  value,
  detail,
}: Props) {
  return (
    <div className="ak-panel rounded-2xl p-5">
      <div className="text-[10px] font-semibold uppercase tracking-[0.2em] text-zinc-600">
        {label}
      </div>

      <div className="mt-3 text-2xl font-semibold tracking-tight text-white">
        {value}
      </div>

      {detail && (
        <div className="mt-1 text-xs text-zinc-600">
          {detail}
        </div>
      )}
    </div>
  );
}
