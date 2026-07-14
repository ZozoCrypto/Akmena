# AgentRegistry Architecture

## Overview

AgentRegistry is the canonical source of identity for the Akmena protocol.

Every protocol participant is represented by a unique Agent record that maps an identifier to an owner address and associated metadata.

---

# Responsibilities

The registry is responsible for:

* registering new agents
* enforcing unique identifiers
* enforcing one agent per owner
* storing metadata references
* tracking metadata versions

The registry is **not** responsible for:

* agreements
* payments
* trust scoring
* verification logic
* treasury operations

Those responsibilities belong to separate protocol modules.

---

# High Level Architecture

```
                    +----------------------+
                    |  External User       |
                    +----------+-----------+
                               |
                               v
                    +----------------------+
                    |   AgentRegistry      |
                    +----------+-----------+
                               |
                               |
                +--------------+--------------+
                |                             |
                v                             v

         Agent Storage               Owner Mapping
```

---

# Agent Structure

Each agent contains:

* id
* owner
* createdAt
* updatedAt
* version
* active
* verified
* metadataURI

The metadataURI points to off-chain metadata describing the agent.

---

# Public Operations

## register()

Creates a new agent.

Requirements:

* identifier must not already exist
* sender must not already own an agent
* metadata must be valid

Effects:

* stores the new agent
* updates owner mapping
* increments total agent count
* emits AgentRegistered

---

## updateMetadata()

Updates an existing agent's metadata.

Requirements:

* agent must exist
* caller must own the agent
* metadata must be valid

Effects:

* updates metadataURI
* increments version
* updates timestamp
* emits MetadataUpdated

---

# Security Properties

The registry should always satisfy the following properties:

* every identifier is unique
* every owner maps to at most one agent
* metadata updates require ownership
* registered agents remain discoverable

These properties are verified by unit, fuzz, and invariant tests.

---

# Design Principles

* simple storage
* explicit interfaces
* custom errors
* event-driven updates
* deterministic state transitions
* test-first development

---

# Future Extensions

Potential additions include:

* verification levels
* delegated operators
* metadata history
* agent deactivation
* registry migration support

These features should preserve the existing interface whenever practical.

---

# Current Status

Version: Draft v1.0

Testing:

* Unit tests ✅
* Fuzz tests ✅
* Invariant tests ✅

This document should be updated whenever public behavior or security assumptions change.
