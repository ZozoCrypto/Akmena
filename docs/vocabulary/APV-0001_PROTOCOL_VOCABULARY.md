# APV-0001
# Akmena Protocol Vocabulary

Status: Living Standard

Version: Draft v0.1

---

# Purpose

This document defines the canonical vocabulary of the Akmena Protocol.

Every specification, proposal, contract, interface, implementation, and audit MUST use these definitions consistently.

If terminology conflicts arise, this document is authoritative.

---

# Agent

An autonomous economic actor capable of participating in the Akmena Protocol.

An Agent MAY be:

• AI system

• Human

• Organization

• DAO

• Service

The protocol does not distinguish intelligence.

It recognizes actors.

---

# Identity

A cryptographically verifiable representation of an Agent.

Identity does not imply trust.

Identity only establishes uniqueness.

---

# Credential

A signed statement describing properties of an identity.

Credentials are issued externally.

The protocol verifies them.

---

# Capability

A permission granted to an Agent.

Capabilities determine what actions an Agent is authorized to perform.

---

# Authorization

A cryptographically signed permission allowing a specific action.

Authorizations are time bounded.

Authorizations are nonce protected.

Authorizations are non-transferable.

---

# Settlement

The irreversible transfer of economic value.

Settlement completes an economic interaction.

---

# Payment

Movement of AKM between participants.

Payment does not imply completion of work.

Settlement does.

---

# Escrow

Temporary custody of value pending protocol-defined conditions.

Escrow protects counterparties.

---

# Agreement

A protocol object describing obligations between participants.

Agreements may reference:

Tasks

Escrow

Credentials

Disputes

Organizations

---

# Task

A unit of work.

Tasks may produce deliverables.

Tasks may be governed by Agreements.

---

# Deliverable

The measurable output of a completed Task.

---

# Registry

The canonical on-chain directory of protocol identities.

---

# Discovery

Mechanisms allowing Agents to locate one another.

Discovery does not imply trust.

---

# Reputation

Historical evidence of prior behavior.

Reputation is informational.

Never authoritative.

---

# Trust

The confidence an Agent places in another Agent.

Trust is computed.

Never assumed.

---

# Organization

A collection of Agents operating under shared governance.

---

# Marketplace

A protocol mechanism matching economic supply and demand.

---

# Protocol

The collection of rules defining Akmena.

Not software.

---

# Reference Implementation

One implementation of the protocol.

Not the protocol itself.

---

# Specification

The authoritative definition of protocol behavior.

---

# ARP

Akmena Research Proposal.

The process by which protocol changes are proposed.

---

# Principle

Words define architecture.

Architecture defines software.