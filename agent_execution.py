import os
from web3 import Web3
from dotenv import load_dotenv

load_dotenv()

# Connect to Base Sepolia
rpc_url = os.environ.get("BASE_SEPOLIA_RPC_URL", "https://sepolia.base.org")
web3 = Web3(Web3.HTTPProvider(rpc_url))

private_key = os.environ.get("PRIVATE_KEY")
account = web3.eth.account.from_key(private_key)

print(f"Connected to Base Sepolia. Agent Address: {account.address}")
print(f"Agent Balance: {web3.from_wei(web3.eth.get_balance(account.address), 'ether')} ETH")

# Verified live PrivacyEngine address
PRIVACY_ENGINE_ADDRESS = "0x7e5079EDE6eDECf3aC59e1d7E36FBE1038Ac9981"
checksum_address = Web3.to_checksum_address(PRIVACY_ENGINE_ADDRESS)

# Verify contract code exists on-chain
code = web3.eth.get_code(checksum_address)
if len(code) > 0:
    print(f"PrivacyEngine verified on-chain! Code size: {len(code)} bytes")
else:
    print("[!] Warning: No contract code found at target address.")

# Test connection via block number check
block_number = web3.eth.block_number
print(f"Current Base Sepolia Block Number: {block_number}")
print("Agent successfully synchronized with the Akmena Protocol network!")
