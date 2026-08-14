import json
from akmena.tools import AkmenaPolicyTool

class MockPolicyModule:
    def get_policy(self, operator_address, agent_address):
        # We simulate web3 throwing an exception if the address is malformed (type confusion)
        if not isinstance(operator_address, str) or not isinstance(agent_address, str):
            raise ValueError("web3: address must be a string")
        return {
            "max_spend_per_tx": 100,
            "daily_limit": 100,
            "spent_today": 0,
            "last_reset": 0,
            "requires_escrow": False
        }

def run_attacks():
    print("=== PHASE G: MCP TOOL VULNERABILITY TESTS ===")
    tool = AkmenaPolicyTool(MockPolicyModule())
    
    # EXPLOIT 1: The Schema Compliance Check
    schema = tool.get_tool_schema()
    is_compliant = "name" in schema["function"] and "parameters" in schema["function"]
    print(f"[*] MCP 2026-07-28 Schema Compliant: {'YES' if is_compliant else 'NO'}")

    # EXPLOIT 2: Type Confusion (LLM hallucinates integers instead of strings)
    # If unhandled, this crashes the MCP server and DoS's the agent.
    result_type_confusion = tool.execute(operator_address=12345, agent_address=67890)
    if "AKMENA SYSTEM ERROR" in result_type_confusion:
        print("[+] Attack Blocked: Type Confusion isolated and returned as string.")
    else:
        print("[-] CRITICAL: Tool execution failed to handle Type Confusion!")

    # EXPLOIT 3: Missing Argument (LLM forgets required parameters)
    try:
        tool.execute(agent_address="0xABC")
        print("[-] CRITICAL: Tool allowed execution without required operator parameter!")
    except TypeError as e:
        print("[+] Attack Blocked: Python native type-checking halted execution.")

if __name__ == "__main__":
    run_attacks()
