import type { ReactNode } from "react";

type Props = {
  title?: string;
  eyebrow?: string;
  children: ReactNode;
  className?: string;
};

export function Panel({
  title,
  eyebrow,
  children,
  className = "",
}: Props) {
  return (
    <section
      className={`ak-panel rounded-2xl p-5 sm:p-6 ${className}`}
    >
      {(eyebrow || title) && (
        <div className="mb-5">
          {eyebrow && (
            <div className="text-[10px] font-semibold uppercase tracking-[0.2em] text-zinc-600">
              {eyebrow}
            </div>
          )}

          {title && (
            <h2 className="mt-1 text-sm font-semibold text-white">
              {title}
            </h2>
          )}
        </div>
      )}

      {children}
    </section>
  );
}
