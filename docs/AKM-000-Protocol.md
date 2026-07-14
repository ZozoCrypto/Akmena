AKM-000 — Akmena Protocol Specification
1. Vision

Akmena is a payment and authorization layer for autonomous AI agents operating on Base.

It enables:

Machine-to-machine (M2M) payments
Gasless delegated execution
Signed intent-based transactions
Programmable financial agents
Real-time settlement between agents, users, and services

Akmena treats intent as currency, and authorization as executable value.

2. Mission

To create a protocol where:

AI agents can independently earn, spend, and settle value without human intervention.

This includes:

Autonomous agents paying other agents
APIs charging per-use via cryptographic authorization
Smart contracts acting as economic participants
Users delegating spending authority to agents safely
3. Core Design Principles
3.1 Intent Over Transactions

Users and agents sign intent, not raw execution.

3.2 Signature-Based Execution

All critical actions are:

cryptographically authorized
replay-protected
time-bound
3.3 Stateless Relayers

Any party can submit valid authorizations.

Relayers are:

trustless
permissionless
replaceable
3.4 Multi-Standard Interoperability

Akmena supports:

ERC-20 (value layer)
ERC-2612 (permit approvals)
ERC-3009 (gasless transfers)
ERC-1363 (execution callbacks)
ERC-165 (interface discovery)
Future: x402 + MCP integration
3.5 AI-Native Design

Agents must be able to:

sign payments
verify spending limits
execute workflows
interact with APIs autonomously

without human confirmation per action.

4. Supported Payment Models
4.1 Direct Transfer

Standard ERC-20 transfer.

4.2 Delegated Approval (ERC-2612)

One-time or time-bound approvals via signature.

4.3 Gasless Transfer (ERC-3009)

Off-chain signed authorization:

transferWithAuthorization
receiveWithAuthorization
cancelAuthorization
4.4 Execution Payments (ERC-1363)

Transfer + callback execution in one atomic transaction.

5. Authorization Model

Each authorization contains:

from
to
value
validAfter
validBefore
nonce
signature

Properties:

Non-repeatable (replay protected)
Time constrained
Stateless verification
Independent from ERC-2612 nonce system
6. Security Model
6.1 Replay Protection

Each (authorizer, nonce) can only be used once.

6.2 Signature Binding

All signatures bind to:

chainId
contract address
domain separator
full transaction struct
6.3 Time Window Enforcement

All authorizations require:

validAfter < block.timestamp < validBefore
6.4 Caller Restrictions (Optional)

Some flows restrict execution caller (e.g. receiveWithAuthorization).

7. Settlement Layer

The protocol assumes:

ERC20 balance state is canonical
All authorized actions resolve into _transfer
No external state required for settlement

Future extensions may include:

streaming payments
batched settlement
conditional execution markets
8. AI Agent Economy Layer

Akmena enables:

Agent Roles:
Paymasters (fund execution)
Workers (perform tasks)
APIs (charge per request)
Coordinators (route payments)
Validators (verify execution)
Agent Capabilities:

Agents can:

hold balances
sign authorizations
execute payments
respond to callbacks
operate continuously
9. Base Network Assumptions

Akmena assumes:

EVM-compatible chain (Base)
low-cost L2 execution
fast finality
reliable event indexing
10. Upgrade Philosophy

Akmena core contracts:

must remain minimal
should be composable
avoid upgradeable proxies in core token
extensions are preferred over mutation
11. Non-Goals

Akmena does NOT attempt to:

replace Ethereum ERC standards
manage identity systems
control agent logic
enforce off-chain behavior
become a full L1/L2
12. Roadmap Alignment

This document supports:

AKM-001: Token Core
AKM-002: Authorization Engine
AKM-003: ERC-1363 Layer
AKM-004: Agent Registry
AKM-005: MCP + x402 integration
End of Specification

This document is the source of truth for all Akmena V1 development.