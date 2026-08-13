# Akmena Python SDK 🛡️

The official Python interface for the **Akmena Protocol** on the Base network.

## The Problem: The "Rogue Agent" Threat
Frameworks like AgentKit give autonomous AI agents the ability to transact on-chain. But giving a probabilistic LLM a funded hot wallet is extremely dangerous. Prompt injections and hallucinations can drain a wallet in seconds.

## The Solution: The Deterministic Firewall
Akmena acts as a **Financial Cage** for your AI agents. 
By routing your agent transactions through the Akmena SDK, you bind the AI to strict, human-defined, on-chain policies. If the AI gets hacked and tries to spend $10,000, our PolicyBoundary smart contracts will cryptographically crush the transaction if you set a $100 daily limit.

---

## 📦 Installation
Install the SDK directly into your Python environment:
`pip install akmena-sdk`

## 🔒 Security Guarantees
- **No Confused Deputies:** Cryptographically verifies the caller against the authorized agent identity.
- **Escrow Validation:** Agents can be forced to mathematically prove funds are locked before executing workflows.
- **Stateless Verification:** The Python SDK relies purely on the EVM state for authorization; it does not store mutable state locally.