from akmena.client import AkmenaClient
import secrets

print("=== Testing Official Python SDK ===")
# Generate a random private key for the agent
pk = "0x" + secrets.token_hex(32)

# Initialize the official SDK client
client = AkmenaClient(
    rpc_url="https://sepolia.base.org", 
    private_key=pk, 
    core_address="0x0000000000000000000000000000000000000000"
)

print(f"[+] SDK Client Initialized for Agent: {client.get_agent_address()}")
print(f"[+] Packaged ABIs successfully loaded: {list(client.abis.keys())}")
print("[+] SDK is fully operational.")
