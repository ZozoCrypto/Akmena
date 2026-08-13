import os
import json
import secrets
from web3 import Web3
from eth_account import Account

# Initialize connection to Base Sepolia
RPC_URL = "http://127.0.0.1:8545"
w3 = Web3(Web3.HTTPProvider(RPC_URL))

def load_abi(contract_name):
    """Dynamically loads the ABI directly from Foundry's out/ directory"""
    path = f"out/{contract_name}.sol/{contract_name}.json"
    if not os.path.exists(path):
        raise FileNotFoundError(f"ABI not found at {path}. Did you run 'forge build'?")
    with open(path, "r") as f:
        return json.load(f)["abi"]

class AkmenaAgent:
    def __init__(self, private_key: str, boundary_address: str):
        self.w3 = w3
        self.account = Account.from_key(private_key)
        self.boundary_abi = load_abi("AkmenaPolicyBoundary")
        
        # Checksum the address
        checksum_addr = self.w3.to_checksum_address(boundary_address)
        self.boundary = self.w3.eth.contract(address=checksum_addr, abi=self.boundary_abi)
        
        print(f"[+] AI Neural Link active. Connected to {RPC_URL}")
        print(f"[+] Agent Hot Wallet Initialized: {self.account.address}")

    def check_policy(self, operator_address: str):
        print(f"\n[*] Querying Akmena Policy Boundary for operator {operator_address}...")
        operator_checksum = self.w3.to_checksum_address(operator_address)
        
        try:
            # Call the public mapping: agentPolicies(operator, agent)
            policy = self.boundary.functions.agentPolicies(operator_checksum, self.account.address).call()
            
            print("\n" + "="*30)
            print("🛡️ AI SPENDING POLICY DETECTED")
            print("="*30)
            print(f"Max Spend Per Tx : {self.w3.from_wei(policy[0], 'ether')} Tokens")
            print(f"Daily Limit      : {self.w3.from_wei(policy[1], 'ether')} Tokens")
            print(f"Spent Today      : {self.w3.from_wei(policy[2], 'ether')} Tokens")
            print(f"Requires Escrow  : {'YES' if policy[4] else 'NO'}")
            print("="*30 + "\n")
            return policy
        except Exception as e:
            print(f"[-] Failed to read policy: {e}")

if __name__ == "__main__":
    print("=== Akmena AI Agent Boot Sequence ===")
    
    if not w3.is_connected():
        print("[-] FATAL: Could not connect to Base Sepolia.")
        exit(1)
        
    print("[+] RPC Connection to Base Sepolia Verified.")
    
    # Generate a temporary ephemeral key just to test the boot sequence
    ephemeral_key = "0x" + secrets.token_hex(32)
    
    # Dummy contract address (we will replace this with your actual deployment address later)
    dummy_boundary = "0x9505575Ca05213D00D59E93Ec4E4374F15A132b9"
    dummy_operator = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
    
    try:
        agent = AkmenaAgent(private_key=ephemeral_key, boundary_address=dummy_boundary)
        agent.check_policy(dummy_operator)
        print("[+] AI Agent Boot Sequence Complete. Ready for Live Deployment Data.")
    except Exception as e:
        print(f"[-] Boot Sequence Failed: {e}")
