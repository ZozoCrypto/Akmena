# Akmena Protocol Threat Model

## Purpose

This document describes the security goals, trust assumptions, protected assets, and expected attack surfaces for the Akmena Agent Registry.

It is intended to evolve alongside the protocol and provide auditors and contributors with a shared understanding of the system.

---

# Scope

Current module:

* AgentRegistry
* IAgentRegistry

Out of scope:

* Agreement Engine
* Trust Engine
* Treasury
* Memory Engine
* SDK/API integrations

---

# Security Goals

The registry must guarantee:

1. Every registered agent has exactly one owner.
2. Agent identifiers are unique.
3. An owner cannot register multiple agents.
4. Metadata updates can only be performed by the owner.
5. Registry state remains internally consistent after any valid transaction.

---

# Protected Assets

## Ownership

The mapping between an agent identifier and its owner must remain correct.

## Identity

Each agent identifier must be unique.

## Metadata

Metadata should only be modifiable by the owning account.

---

# Threat Actors

## Malicious User

Attempts to:

* register duplicate agents
* overwrite another user's metadata
* spam the registry

## Compromised Frontend

Displays incorrect information or tricks users into submitting unintended transactions.

The smart contract should remain the source of truth.

## External Integrator Bugs

Third-party applications may misuse the interface or make incorrect assumptions.

The protocol should fail safely.

---

# Trust Assumptions

The protocol assumes:

* Ethereum/Base consensus is functioning correctly.
* Solidity compiler version 0.8.28 behaves as expected.
* OpenZeppelin dependencies are trusted and unmodified.
* Users control their own private keys.

---

# Known Attack Surfaces

## Registration

Attackers may attempt duplicate registrations or malformed metadata.

Mitigations:

* unique identifier checks
* owner uniqueness checks
* metadata validation

## Metadata Updates

Attackers may attempt unauthorized updates.

Mitigation:

* strict ownership verification

---

# Current Security Controls

* Custom errors
* Unit tests
* Fuzz tests
* Invariant tests
* Explicit interface definition
* Immutable registry owner

---

# Future Reviews

Before AgentRegistry v1.0 release:

* Storage layout review
* Gas review
* Static analysis
* External audit
* Documentation review
* Continuous integration verification

---

# Version

Draft: AgentRegistry v1.0 Preparation
