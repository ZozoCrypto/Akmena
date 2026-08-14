from akmena.modules.x402 import X402Verifier

def run_attacks():
    print("=== PHASE H: x402 PAYMENT PROTOCOL VULNERABILITY TESTS ===")
    verifier = X402Verifier()
    
    # 1. The Valid AI Payment
    valid_tx = "0x" + "a" * 64
    payment_id = "akmena_req_987654321"
    
    print("[*] AI Agent submits valid x402 payment payload...")
    try:
        success = verifier.verify_payment(valid_tx, payment_id)
        if success:
            print("[+] Payment Verified. Service Fulfilled to Agent.")
    except Exception as e:
        print(f"[-] Unexpected Error: {e}")

    # 2. EXPLOIT ATTEMPT: Replay Attack
    print("\n[*] ATTACKER intercepts payload and replays identical x402 headers...")
    try:
        # Attacker submits the exact same hash and payment ID hoping for a second fulfillment
        verifier.verify_payment(valid_tx, payment_id)
        print("[-] CRITICAL: Attacker achieved MULTIPLE Fulfillments from ONE Payment!")
    except PermissionError as e:
        print(f"[+] Attack Blocked: {e}")

if __name__ == "__main__":
    run_attacks()
