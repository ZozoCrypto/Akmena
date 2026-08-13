import json

class AkmenaPolicyTool:
    """
    A standard tool interface compatible with LangChain, AutoGen, and AgentKit.
    Provides the LLM a native JSON schema to autonomously check its own limits.
    """
    name = "check_akmena_policy"
    description = (
        "Check the on-chain Akmena spending policy and daily limits for an AI agent "
        "before attempting to execute a transaction on the Base network."
    )

    def __init__(self, policy_module):
        self.policy_module = policy_module

    def get_tool_schema(self) -> dict:
        """Returns the JSON Schema required by OpenAI/AgentKit for function calling."""
        return {
            "type": "function",
            "function": {
                "name": self.name,
                "description": self.description,
                "parameters": {
                    "type": "object",
                    "properties": {
                        "operator_address": {
                            "type": "string",
                            "description": "The Ethereum address of the human operator"
                        },
                        "agent_address": {
                            "type": "string",
                            "description": "The Ethereum address of the AI agent's hot wallet"
                        }
                    },
                    "required": ["operator_address", "agent_address"]
                }
            }
        }

    def execute(self, operator_address: str, agent_address: str) -> str:
        """Executes the on-chain check and returns a stringified result for the LLM."""
        try:
            limits = self.policy_module.get_policy(operator_address, agent_address)
            # Convert Web3 types to standard strings/ints for the LLM
            readable_limits = {
                "max_spend_per_transaction": str(limits["max_spend_per_tx"]),
                "daily_limit_remaining": str(limits["daily_limit"] - limits["spent_today"]),
                "requires_active_escrow": limits["requires_escrow"]
            }
            return f"AKMENA POLICY: {json.dumps(readable_limits)}"
        except Exception as e:
            return f"AKMENA SYSTEM ERROR: {str(e)}"
