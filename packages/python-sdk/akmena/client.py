import json
import os
from web3 import Web3
from eth_account import Account
from .modules.policy import PolicyModule

class AkmenaClient:
    """
    The primary SDK client for interacting with the Akmena Protocol.
    """
    def __init__(self, rpc_url: str, private_key: str, core_address: str):
        self.w3 = Web3(Web3.HTTPProvider(rpc_url))
        if not self.w3.is_connected():
            raise ConnectionError(f"Failed to connect to RPC: {rpc_url}")
            
        self.account = Account.from_key(private_key)
        self.core_address = self.w3.to_checksum_address(core_address)
        
        # Automatically load packaged ABIs
        self.abis = self._load_abis()
        self.core = self.w3.eth.contract(address=self.core_address, abi=self.abis["AkmenaCore"])
        
    def _load_abis(self) -> dict:
        abis = {}
        abi_dir = os.path.join(os.path.dirname(__file__), "abis")
        for filename in os.listdir(abi_dir):
            if filename.endswith(".json"):
                name = filename[:-5]
                with open(os.path.join(abi_dir, filename), "r") as f:
                    abis[name] = json.load(f)
        return abis

    def get_agent_address(self) -> str:
        return self.account.address
        
    def get_policy_module(self, boundary_address: str) -> PolicyModule:
        return PolicyModule(self, boundary_address, self.abis["AkmenaPolicyBoundary"])
