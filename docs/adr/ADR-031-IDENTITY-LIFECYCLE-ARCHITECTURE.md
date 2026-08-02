# ADR-031 — Identity Lifecycle Architecture

**Status:** Accepted

**Date:** 2026-08-01

---

# Context

Earlier protocol drafts distributed responsibility for identity creation, numbering, ownership, and registration across multiple components.

This approach increased coupling between modules and complicated future scalability.

Akmena V2 adopts a strict separation of responsibilities that mirrors mature distributed systems architecture.

---

# Identity Lifecycle

The canonical lifecycle SHALL be:

Registry

↓

Allocate Identity ID

↓

Identity Factory

↓

Deploy ERC-1167 Clone


↓

Initialize Identity

↓

Register Identity

↓

Protocol Active
```

No component SHALL bypass this lifecycle.

---

# Responsibility Model

## Registry

The Registry SHALL:

* Allocate canonical protocol identity identifiers.
* Maintain the immutable participant index.
* Resolve identity identifiers to contract addresses.
* Resolve contract addresses to identity identifiers.
* Provide protocol discovery services.
* Preserve historical registration records.

The Registry SHALL NOT:

* Deploy contracts.
* Modify participant state.
* Execute protocol logic.
* Assign permissions.
* Manage balances.

The Registry is a directory service.

---

## Identity Factory

The Identity Factory SHALL:

* Deploy ERC-1167 minimal proxy clones.
* Initialize newly deployed identities.
* Register completed identities with the Registry.

The Identity Factory SHALL NOT:

* Allocate protocol identifiers.
* Store participant metadata.
* Maintain protocol indexes.
* Own participant state.

The Factory is a deployment service.

---

## Identity

Identity contracts SHALL:

* Represent a single protocol participant.
* Maintain participant state.
* Maintain ownership.
* Maintain activation status.
* Maintain immutable participant type.
* Expose protocol metadata.

Identity contracts SHALL NOT:

* Register themselves.
* Allocate identifiers.
* Discover other participants.
* Execute marketplace logic.
* Hold protocol indexes.

Identity contracts are protocol objects.

---

# Identity Identifier

Every participant SHALL possess one immutable protocol identifier.

Properties:

* Allocated only by the Registry.
* Never reused.
* Never modified.
* Never recycled.
* Never reassigned.

Identity identifiers are permanent protocol references.

---

# Reserved Identifier

Identity identifier:

```
0
```

is permanently reserved.

Identity ID zero SHALL NEVER represent a participant.

Identity ID zero represents an uninitialized or invalid protocol reference.

---

# Address Semantics

Ethereum addresses are implementation details.

Protocol identity identifiers are protocol references.

Accordingly:

Internal protocol modules SHOULD exchange immutable identity identifiers whenever practical.

Ethereum addresses SHOULD be resolved through the Registry.

---

# Hybrid Identity Model

The protocol distinguishes between:

## Internal Identity

Canonical reference:

```
Identity ID
```

Used by:

* Authorization
* Marketplace
* Escrow
* Settlement
* Reputation
* Memory
* Governance

---

## External Identity

Canonical reference:

```
Ethereum Address
```

Used by:

* Wallet interaction
* ERC standards
* Transaction signing
* Off-chain clients
* Block explorers
* RPC interfaces
* External integrations

The Registry forms the bridge between these two identity domains.

---

# Protocol Invariants

The following SHALL always hold:

Every identity owns exactly one immutable protocol identifier.

Every protocol identifier resolves to at most one active identity.

Every identity contract resolves to exactly one protocol identifier.

Identity identifiers SHALL never change.

Historical identity identifiers SHALL remain valid indefinitely.

---

# Future Compatibility

This architecture supports future protocol extensions including:

* Cross-chain identities
* Identity migration
* Identity recovery
* Identity federation
* Bridged identities
* Trusted execution environments
* Autonomous AI agents
* Hardware-backed machine identities

No changes to the lifecycle defined herein SHALL be required to support these capabilities.

---

# Engineering Consequences

All future protocol modules SHALL reference protocol participants through immutable identity identifiers internally.

External APIs SHALL continue to expose Ethereum addresses where interoperability with existing Ethereum tooling and standards requires them.

The Registry SHALL provide canonical resolution between protocol identifiers and blockchain addresses.

This preserves compatibility with the Ethereum ecosystem while ensuring stable internal protocol references.

---

# Rationale

This architecture separates identity management into three independent responsibilities:

* Registry — identity allocation and discovery.
* Identity Factory — deployment.
* Identity — participant state.

This separation minimizes coupling, reduces audit complexity, simplifies testing, improves scalability, and aligns with the Akmena Engineering Constitution.

---

# Decision

ADR-031 is accepted.

The Identity Lifecycle Architecture defined herein is the canonical identity architecture for Akmena Protocol V2.

Any future deviation SHALL require a superseding ADR.
