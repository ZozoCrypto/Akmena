# THREAT_MODEL.md

Version: v2.0.0-rc.1

Status: Canonical

---

# Purpose

This document defines the canonical threat model for the Akmena Protocol.

Its purpose is to identify:

* protocol assets,
* trust boundaries,
* attacker capabilities,
* security assumptions,
* invariants,
* accepted risks,
* mitigation strategies.

This document is normative.

Future protocol changes SHALL remain consistent with this threat model unless superseded by a future ADR.

---

# Security Philosophy

Akmena follows the Engineering Constitution.

Core principles include:

* Trust nothing by default.
* Lower protocol layers never trust upper layers.
* Money never depends on AI.
* Identity is immutable.
* Every state transition is explicit.
* Every critical transition is testable.
* Every privileged action is observable.

Security is achieved through isolation rather than complexity.

---

# Protected Assets

The protocol protects the following assets.

## User Funds

Held within:

* EscrowEngine
* SettlementEngine

Requirements:

* Cannot be stolen
* Cannot be double-spent
* Cannot become permanently locked
* Cannot bypass settlement rules

---

## Identity

Every participant possesses one immutable protocol identity.

Identity guarantees:

* uniqueness
* immutability
* permanent historical reference

---

## Reputation

Reputation must satisfy:

* deterministic updates
* append-only history
* resistance to arbitrary manipulation

---

## Memory

Agent memories represent historical protocol facts.

Memory records:

* cannot silently disappear
* cannot be rewritten
* remain permanently auditable

---

## Governance

Governance controls protocol evolution.

Governance must never allow:

* instant upgrades
* hidden upgrades
* privilege escalation
* parameter modification outside protocol rules

---

# Trust Boundaries

## Layer 1

Identity

No dependencies.

---

## Layer 2

Authorization

Depends only on Identity.

---

## Layer 3

Marketplace

Depends on Identity and Authorization.

---

## Layer 4

Agreements

Cannot bypass Authorization.

---

## Layer 5

Escrow

Never trusts Marketplace.

Escrow only trusts Agreements.

---

## Layer 6

Settlement

Never trusts Workflow.

Settlement only trusts Escrow state.

---

## Layer 7

Memory

Records protocol facts.

Never changes protocol state.

---

## Layer 8

Reputation

Consumes protocol events.

Never controls protocol execution.

---

## Layer 9

Workflow Engine

Acts only as an orchestrator.

Owns:

* no funds
* no permissions
* no protocol authority

---

## SDK

Never trusted.

SDK exists only for developer convenience.

Every SDK request must satisfy the same on-chain validation.

---

# Threat Actors

## External Attacker

Capabilities:

* arbitrary transactions
* frontrunning
* replay attempts
* malicious calldata

Cannot:

* bypass authorization
* forge identities
* violate protocol invariants

---

## Malicious Agent

Capabilities:

* valid protocol identity
* valid wallet
* malicious intent

Cannot:

* steal escrow
* forge governance
* impersonate another identity

---

## Compromised Workflow Engine

Capabilities:

* malformed orchestration

Cannot:

* bypass module authorization
* bypass settlement
* bypass escrow
* bypass governance

---

## Malicious Governor

Governance proposals remain subject to:

* voting
* timelock
* guardian veto (before sunset)

---

# Security Assumptions

The protocol assumes:

Ethereum cryptography remains secure.

ECDSA remains secure.

Base consensus remains secure.

OpenZeppelin dependencies remain trustworthy.

Users protect private keys.

No assumption is made regarding:

SDK correctness.

Frontend correctness.

RPC correctness.

These components are untrusted.

---

# Critical Invariants

The following properties must never fail.

## Identity

Every identity owns exactly one immutable ID.

---

## Escrow

Funds may only move through:

Created

↓

Funded

↓

Released

or

Refunded

No alternate path exists.

---

## Settlement

Settlement cannot execute twice.

---

## Workflow

Workflow owns no protocol authority.

---

## Governance

Every governance action passes through:

Proposal

↓

Vote

↓

Timelock

↓

Execution

No bypass exists.

---

## Registry

Protocol identifiers are immutable.

---

# Attack Surface

Externally callable contracts:

* AkmenaCore
* AgentRegistry
* IdentityFactory
* EscrowEngine
* WorkflowEngine
* Governance
* Timelock

Every public function must enforce:

* authorization
* validation
* invariant preservation

---

# Mitigations

Current mitigations include:

* explicit state machines
* immutable protocol IDs
* ERC-7201 storage isolation
* stateless orchestration
* module isolation
* typed governance actions
* timelocked upgrades
* fuzz testing
* invariant testing
* symbolic execution
* static analysis

---

# Accepted Risks

The protocol intentionally accepts:

Low-level ETH transfer via call()

Canonical ERC-1167 deployment assembly

Upgradeable OpenZeppelin compiler ranges

These risks are documented in SECURITY_REPORT.md.

---

# Incident Response

If a critical vulnerability is discovered before Guardian sunset:

1. Pause affected modules if supported.
2. Guardian veto pending governance proposals.
3. Publish incident disclosure.
4. Deploy patched implementation.
5. Execute governed upgrade.

After Guardian sunset:

Only governance may modify protocol behavior.

---

# Verification

Security validation currently includes:

* Unit Tests
* Integration Tests
* Stateful Invariants
* Fuzz Testing
* Chaos Testing
* Symbolic Execution
* Slither Static Analysis

Additional external audits are planned before mainnet deployment.

---

# Conclusion

The Akmena Protocol security model relies on:

* minimal trust,
* strict layer separation,
* immutable identity,
* explicit state machines,
* deterministic governance,
* and comprehensive automated verification.

Protocol correctness derives from independently secure modules rather than privileged orchestration layers.

This threat model is adopted as the canonical security model for Akmena Protocol V2.
