from web3.contract import Contract

class PolicyModule:
    """Interfaces with the AkmenaPolicyBoundary contract."""
    
    def __init__(self, client, boundary_address: str, abi: list):
        self.client = client
        self.contract = self.client.w3.eth.contract(
            address=self.client.w3.to_checksum_address(boundary_address),
            abi=abi
        )

    def get_policy(self, operator_address: str, agent_address: str) -> dict:
        """Fetches the strict mathematical spending limits for an AI agent."""
        op_checksum = self.client.w3.to_checksum_address(operator_address)
        agent_checksum = self.client.w3.to_checksum_address(agent_address)
        
        raw_policy = self.contract.functions.agentPolicies(op_checksum, agent_checksum).call()
        
        return {
            "max_spend_per_tx": raw_policy[0],
            "daily_limit": raw_policy[1],
            "spent_today": raw_policy[2],
            "last_reset": raw_policy[3],
            "requires_escrow": raw_policy[4]
        }
