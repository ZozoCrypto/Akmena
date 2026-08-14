class X402Verifier:
    """
    Handles 402 Payment Required validation for Machine-to-Machine (M2M) Agent economies.
    Strictly enforces idempotency to prevent Replay Attacks on valid AI transactions.
    """
    def __init__(self):
        # In production, this maps to a Redis cache or Postgres DB. 
        # For the SDK memory runtime, we use a set.
        self.processed_payments = set()

    def verify_payment(self, tx_hash: str, payment_id: str, expected_chain: str = "eip155:84532") -> bool:
        """
        Verifies that an x402 payment is valid and has NOT been used for fulfillment before.
        """
        if not tx_hash.startswith("0x") or len(tx_hash) != 66:
            raise ValueError("x402 Error: Invalid Transaction Hash format.")

        # [PATCH ZERO-DAY]: Prevent Multiple Fulfillments from One Payment
        if payment_id in self.processed_payments:
            raise PermissionError(f"x402 Error: Payment Replay Detected for ID {payment_id}")

        # (In a full environment, we would also query the RPC here to ensure tx_hash 
        # actually moved the required funds to the merchant address on expected_chain)
        
        # Lock the payment identifier so it can never be used again
        self.processed_payments.add(payment_id)
        return True
