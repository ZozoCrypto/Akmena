# BOOK I

# Monetary Layer

## 1. Purpose

The Monetary Layer provides deterministic value transfer for autonomous commerce.

Every higher protocol layer depends upon the guarantees established here.

No protocol component may weaken these guarantees.

The Monetary Layer SHALL remain the most stable layer of the Akmena Protocol.

---

## 2. Objectives

The Monetary Layer SHALL provide:

• Fixed monetary supply

• Deterministic settlement

• Cryptographic authorization

• Machine-to-machine payments

• Human-to-machine payments

• Human-to-human payments

• Replay protection

• Gas-efficient transfers

• Smart contract interoperability

---

## 3. Components

The Monetary Layer consists of:

• AKM Token

• ERC20

• ERC2612 Permit

• ERC3009 Authorization

• ERC1363 Callbacks

• Settlement Engine

---

## 4. Design Principles

The Monetary Layer SHALL NOT know:

• Registry

• Reputation

• Escrow

• Organizations

• Marketplace

• Agreements

• AI Agents

The Monetary Layer SHALL only know how to securely transfer value.


---

# Monetary Invariants

The following conditions MUST always remain true.

Invariant M1

Total supply SHALL NEVER exceed MAX_SUPPLY.

Invariant M2

Every successful transfer SHALL conserve supply.

Invariant M3

Every authorization SHALL execute at most once.

Invariant M4

Every authorization SHALL expire.

Invariant M5

No replay SHALL ever succeed.

Invariant M6

Token balances SHALL never become negative.

Invariant M7

Permit signatures SHALL remain independent of authorization nonces.

Invariant M8

Settlement SHALL remain deterministic.

Invariant M9

The Monetary Layer SHALL remain independent from every higher protocol layer.


---