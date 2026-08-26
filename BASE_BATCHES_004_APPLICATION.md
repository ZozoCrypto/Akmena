# Base Batches 004 Application: Akmena

## 1. What are you building? (One sentence)
Akmena is a nuclear-hardened smart contract and privacy protocol designed to provide secure, autonomous execution, trustless escrow, and stealth settlements for AI agents on Base.

## 2. Explain your project in more detail.
Traditional Web3 infrastructure lacks the security and transient memory isolation required for autonomous AI agents to execute complex economic operations safely. Akmena solves this through an advanced **ERC-8109 Diamond Proxy** architecture paired with **EIP-1153** transient state proofs and cryptographic nullifiers (Ghost Mode). 

The protocol is structured across three core layers:
- **Execution & Authorization Boundary:** Enforces strict policy limits, per-transaction spend caps, and cryptographic intent binding to prevent agent hijacking or payload substitution.
- **Escrow & Settlement Engines:** Trustlessly locks and routes capital between autonomous agents and counterparties on-chain.
- **The Singularity UI:** A production-grade frontend built using **Coinbase OnchainKit** and Wagmi, providing real-time telemetry, wallet connection, and contract execution tools.

## 3. What is your traction or current state of development?
- **Smart Contracts Deployed:** 11 core contracts successfully audited via Foundry and Slither (0 vulnerabilities), deployed, and verified live on **Base Sepolia** (Chain ID: 84532).
- **Autonomous Agent SDK:** A functional Python execution agent (`web3.py`) communicating directly with protocol storage and nullifier registries.
- **Testing & Quality Assurance:** Backed by automated attack vector test suites in Foundry and headless browser UI audits via Playwright.

## 4. Why Base?
Akmena relies on rapid finality and low transaction costs to support high-frequency autonomous agent loops. Base provides the premier L2 execution environment and developer ecosystem required to scale agentic finance securely.
