import json
from pathlib import Path

# Resolve paths from the repository root so this script works whether it is
# invoked from the repo root, packages/sdk, or another working directory.
REPO_ROOT = Path(__file__).resolve().parents[1]
ROOT = REPO_ROOT / "out"
DEST = REPO_ROOT / "packages/sdk/src/abis"

CONTRACTS = {
    "AkmenaCore": "AkmenaCore.sol",
    "EscrowEngine": "EscrowEngine.sol",
    "PaymentsEngine": "PaymentsEngine.sol",
    "WorkflowEngine": "WorkflowEngine.sol",
    "AgentRegistry": "AgentRegistry.sol",
    "EconomicCommitmentEngine": "EconomicCommitmentEngine.sol",
    "MarketplaceEngine": "MarketplaceEngine.sol",
}

DEST.mkdir(parents=True, exist_ok=True)

for contract, artifact_dir in CONTRACTS.items():
    artifact = ROOT / artifact_dir / f"{contract}.json"

    if not artifact.exists():
        raise SystemExit(f"Missing Foundry artifact: {artifact}")

    data = json.loads(artifact.read_text())
    abi = data.get("abi", [])

    output = (
        f"// AUTO-GENERATED FROM FOUNDRY ARTIFACT\n"
        f"// Source: {artifact}\n"
        f"// DO NOT EDIT MANUALLY.\n\n"
        f"export const {contract}ABI = "
        + json.dumps(abi, indent=2)
        + " as const;\n"
    )

    destination = DEST / f"{contract}.ts"
    destination.write_text(output)
    print(f"[+] Generated {destination}")

print("[+] TypeScript ABI generation complete.")
