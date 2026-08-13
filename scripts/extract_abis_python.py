import os
import json

TARGET_CONTRACTS = [
    "AkmenaCore",
    "AkmenaPolicyBoundary",
    "EscrowEngine",
    "AgreementEngine",
    "AgentRegistry",
    "SettlementEngine"
]

OUT_DIR = "out"
DEST_DIR = "packages/python-sdk/akmena/abis"

os.makedirs(DEST_DIR, exist_ok=True)

for contract in TARGET_CONTRACTS:
    src_path = os.path.join(OUT_DIR, f"{contract}.sol", f"{contract}.json")
    dest_path = os.path.join(DEST_DIR, f"{contract}.json")
    
    if os.path.exists(src_path):
        with open(src_path, "r") as f:
            data = json.load(f)
        
        with open(dest_path, "w") as f:
            json.dump(data.get("abi", []), f, indent=2)
        print(f"[+] Extracted ABI: {contract}")
    else:
        print(f"[-] Missing: {src_path}")
