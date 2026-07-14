# BOOK V
# Protocol APIs

Version: Draft v0.1

---

## Purpose

This book defines every canonical protocol interface exposed by Akmena.

These interfaces represent the public contract between the protocol and developers.

Implementations may change.

Interfaces may not.

---

## Design Philosophy

Every interface must satisfy five rules.

1. Stable

Interfaces should remain compatible for years.

2. Predictable

Every method has one responsibility.

3. Composable

Interfaces should compose naturally with other protocol modules.

4. Deterministic

Identical inputs produce identical outputs.

5. Minimal

No unnecessary complexity.

---

## Protocol API Layers

Layer 1

Monetary APIs

• AKM Token

• Authorization

• Payments

Layer 2

Trust APIs

• Registry

• Reputation

• Escrow

Layer 3

Agent APIs

• Marketplace

• Discovery

• Skills

• Organizations

Layer 4

Application APIs

Applications built on top of Akmena.

---

## Canonical Interfaces

Every protocol module publishes exactly one canonical interface.

Examples

IAKMToken

IAgentRegistry

IEscrow

ISettlement

IReputation

IDiscovery

IOrganization

No implementation details appear inside the specification.

Only behavior.

---

## Events

Events are first-class protocol objects.

Events MUST be deterministic.

Events MUST never change meaning.

Applications should rely on events rather than storage whenever possible.

---

## Versioning

Interfaces evolve using semantic versioning.

Major

Breaking change

Minor

Backward-compatible features

Patch

Clarifications only

---

## Compatibility

Akmena follows Open Standards whenever possible.

ERC-20

ERC-2612

ERC-3009

ERC-1363

EIP-712

Future ERC standards may be adopted without changing protocol philosophy.

---

## Protocol Principle

Applications integrate with interfaces.

Never implementations.