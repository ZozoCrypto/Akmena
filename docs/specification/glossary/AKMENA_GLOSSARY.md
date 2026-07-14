# Akmena Protocol Glossary

Version 1.0

Status: Normative

---

# Purpose

This glossary defines the canonical meaning of protocol terminology.

Every specification, implementation, proposal, audit, and research document shall use these definitions unless explicitly stated otherwise.

---

# Agent

An autonomous or human-controlled entity capable of participating in the Akmena Protocol.

Agents may represent:

• AI systems

• Humans

• Organizations

• Services

• DAOs

Agents possess identity, permissions, capabilities, and reputation.

---

# Agreement

A cryptographically defined relationship between two or more participants describing obligations, conditions, deliverables, and settlement rules.

---

# Authorization

A signed permission allowing an action to be executed without requiring the signer to submit the transaction directly.

Authorizations are time-bound, replay-protected, and cryptographically verifiable.

---

# Capability

A permission granted to an agent allowing execution of a specific action.

Capabilities are more granular than roles.

---

# Credential

A verifiable claim issued to an identity.

Credentials may represent:

• certifications

• licenses

• memberships

• attestations

• completed work

---

# Escrow

A protocol primitive responsible for temporarily locking assets until predefined settlement conditions are satisfied.

Escrow itself never determines outcomes.

---

# Identity

A persistent protocol representation of an entity.

Identity is independent from wallets.

A single identity may control multiple wallets.

---

# Intent

A signed expression describing the desired outcome of an action rather than the execution path.

---

# Layer

A protocol abstraction with a single responsibility.

Higher layers depend upon lower layers.

Lower layers never depend upon higher layers.

---

# Primitive

A minimal protocol component that performs one deterministic responsibility.

Examples include:

• Token

• Escrow

• Registry

• Reputation

---

# Proof

Cryptographic evidence demonstrating that a statement or computation is valid.

Proofs may be generated using zero-knowledge systems, attestations, or digital signatures.

---

# Protocol

The collection of specifications defining behavior independent of any implementation.

---

# Registry

A protocol primitive responsible for maintaining canonical records of identities, organizations, services, or other registered objects.

---

# Reputation

A persistent measure of observed behavior accumulated through protocol interactions.

Reputation is earned.

It cannot be transferred.

---

# Settlement

The irreversible completion of a protocol agreement resulting in final state transition.

---

# Standard

A formally accepted protocol rule.

Standards originate from accepted research proposals.

---

# Trust

The measurable confidence that an agent will satisfy future obligations based upon verifiable evidence.

Trust is computed.

It is not declared.

---

# Wallet

A cryptographic key management tool used to authorize protocol interactions.

Wallets are authentication mechanisms.

They are not identities.

---

# Organization

A protocol-recognized entity capable of owning assets, issuing credentials, managing policies, and coordinating agents.

---

# Engine

A deterministic software module implementing one protocol primitive or protocol service.

---

# Reference Implementation

The official implementation used to demonstrate protocol compliance.

Reference implementations never define protocol behavior.

The specification always remains authoritative.

---

# Compliance

The property of an implementation correctly following the protocol specification.

Passing tests alone does not guarantee compliance.

Compliance requires conformance to the normative specification.

---

# Canonical

The official source of truth recognized by the protocol.

---

# Deterministic

Producing identical results from identical inputs without ambiguity.

---

# Normative

Text that defines mandatory protocol behavior.

Normative statements use terms such as MUST, SHALL, SHOULD, MAY, and MUST NOT.

---

# Informative

Text intended to explain concepts without imposing protocol requirements.

---

End of Glossary.
