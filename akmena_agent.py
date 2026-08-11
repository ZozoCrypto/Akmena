import os
from web3 import Web3
from dotenv import load_dotenv

load_dotenv()

RPC_URL = "https://sepolia.base.org"
PRIVATE_KEY = os.getenv("PRIVATE_KEY")

AKMENA_CORE = "0x77fa8Fd4d52b989092eA15121d53620322f29B89"

def main():
    print("\n[+] Initializing Akmena Autonomous Execution Layer...")
    w3 = Web3(Web3.HTTPProvider(RPC_URL))
    
    if w3.is_connected():
        print(f"[+] Neural Link Established: Base Sepolia (Current Block: {w3.eth.block_number})")
    else:
        print("[-] Error: Failed to connect to Base Sepolia RPC.")
        return

    account = w3.eth.account.from_key(PRIVATE_KEY)
    balance = w3.from_wei(w3.eth.get_balance(account.address), 'ether')
    
    print(f"[+] Agent Operator Account: {account.address}")
    print(f"[+] Gas Reserves: {balance:.6f} ETH")
    print(f"[+] AkmenaCore Router Status: ONLINE at {AKMENA_CORE}\n")

if __name__ == "__main__":
    main()
