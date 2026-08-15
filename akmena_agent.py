import os
from dotenv import load_dotenv
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_core.tools import StructuredTool
from pydantic import BaseModel, Field
from langgraph.prebuilt import create_react_agent

# Akmena Protocol Imports
from akmena.tools import AkmenaPolicyTool

# 1. Load Secure Environment Variables
load_dotenv()
GOOGLE_API_KEY = os.getenv("GOOGLE_API_KEY", "")
AGENT_PRIVATE_KEY = os.getenv("AGENT_PRIVATE_KEY", "0x" + "1" * 64)
OPERATOR_ADDRESS = os.getenv("HUMAN_OPERATOR_ADDRESS", "0xAD11111111111111111111111111111111111111")
AGENT_ADDRESS = "0x2222222222222222222222222222222222222222" # Mock agent address

# 2. Mock the On-Chain State (Until we deploy V2 to Sepolia)
class MockPolicyModule:
    def get_policy(self, operator_address, agent_address):
        print(f"\n[EVM CALL] Querying AkmenaPolicyBoundary for Agent {agent_address[:8]}...")
        return {
            "max_spend_per_tx": 100,
            "daily_limit": 1000,
            "spent_today": 250,
            "last_reset": 0,
            "requires_escrow": True
        }

def initialize_ghost_bundler():
    print("=== WAKING UP THE GHOST-BUNDLER (GEMINI 3.6 EDITION) ===")
    print(f"[*] Agent EVM Identity Bound: {AGENT_ADDRESS}")

    # 3. Instantiate the Protocol Tooling
    raw_policy_tool = AkmenaPolicyTool(MockPolicyModule())

    # LangChain strict type schema
    class PolicyCheckInput(BaseModel):
        operator_address: str = Field(description="The Ethereum address of the human operator")
        agent_address: str = Field(description="The Ethereum address of the AI agent's hot wallet")

    # Wrap for LangGraph integration
    langchain_policy_tool = StructuredTool.from_function(
        func=raw_policy_tool.execute,
        name=raw_policy_tool.name,
        description=raw_policy_tool.description,
        args_schema=PolicyCheckInput
    )

    tools = [langchain_policy_tool]

    # 4. Initialize the Cognitive Engine (Upgraded to Gemini 3.6 Flash)
    llm = ChatGoogleGenerativeAI(model="gemini-3.6-flash", temperature=0.0)

    # 5. Construct the Reasoning Loop
    agent = create_react_agent(llm, tools)

    return agent

if __name__ == "__main__":
    if not GOOGLE_API_KEY:
        print("[-] WARNING: GOOGLE_API_KEY not set. Execution will fail.")
    else:
        ghost_bundler = initialize_ghost_bundler()
        
        system_prompt = (
            "You are the 'Ghost-Bundler', an autonomous quantitative trading and execution agent operating on the Base network. "
            "You are secured by the Akmena Protocol deterministic firewall. "
            "You must ALWAYS use your tools to check your on-chain Akmena policy limits before answering questions about your spending power. "
            f"Your EVM address is {AGENT_ADDRESS}. Your human operator is {OPERATOR_ADDRESS}."
        )

        print("\n=== EXECUTING DIRECTIVE ===")
        try:
            inputs = {"messages": [
                ("system", system_prompt),
                ("user", "Initialize systems. Run a diagnostic to check our current spending limits on the Akmena Protocol firewall. Can I spend 500 ETH today in a single transaction?")
            ]}
            
            for s in ghost_bundler.stream(inputs, stream_mode="values"):
                message = s["messages"][-1]
                message.pretty_print()
                
        except Exception as e:
            print(f"\n[-] Execution Error: {e}")
