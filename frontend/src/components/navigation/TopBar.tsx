import { StatusPill } from "../status/StatusPill";

type Props = {
  wallet?: `0x${string}`;
  chainId?: number;
};

function shortAddress(
  address?: string,
) {
  if (!address) {
    return "Not connected";
  }

  return `${address.slice(0, 6)}...${address.slice(-4)}`;
}

export function TopBar({
  wallet,
  chainId,
}: Props) {
  const baseSepolia =
    chainId === 84532;

  return (
    <header className="sticky top-0 z-20 border-b border-white/8 bg-[#050608]/80 backdrop-blur-xl">
      <div className="flex min-h-16 items-center justify-between gap-4 px-5 sm:px-8">
        <div>
          <div className="text-[10px] font-semibold uppercase tracking-[0.22em] text-zinc-600">
            Autonomous Economic Infrastructure
          </div>
          <div className="mt-1 text-sm font-medium text-zinc-200">
            Execution Control Center
          </div>
        </div>

        <div className="flex items-center gap-3">
          <StatusPill
            label={
              baseSepolia
                ? "Base Sepolia"
                : chainId
                  ? `Chain ${chainId}`
                  : "Network"
            }
            status={
              baseSepolia
                ? "success"
                : "warning"
            }
          />

          <div className="hidden rounded-xl border border-white/8 bg-white/[0.03] px-3 py-2 sm:block">
            <div className="text-[10px] uppercase tracking-[0.18em] text-zinc-600">
              Wallet
            </div>
            <div className="mt-0.5 text-xs text-zinc-300 ak-mono">
              {shortAddress(wallet)}
            </div>
          </div>
        </div>
      </div>
    </header>
  );
}
