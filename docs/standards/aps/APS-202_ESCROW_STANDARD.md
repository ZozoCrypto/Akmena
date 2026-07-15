# APS-202

# Escrow Standard

Version: 1.0

Status: Draft

Category: Economic Layer

Authority: Protocol Standard

Classification: Normative

---

# Purpose

This standard defines escrow as the protocol primitive responsible for conditional settlement.

Escrow enables participants to commit value while delaying final settlement until predefined protocol conditions have been satisfied.

Escrow is a coordination mechanism.

It is not arbitration.

It is not governance.

It is not settlement.

Escrow governs the transition between obligation and settlement.

---

# Scope

This standard governs:

* escrow creation
* funding
* locking
* conditional release
* refund
* expiration
* cancellation
* settlement integration

---

# Escrow Principles

Escrow SHALL preserve:

* value integrity
* deterministic behavior
* auditability
* neutrality
* reversibility before settlement
* irreversibility after settlement

---

# Escrow Lifecycle

Every escrow SHALL progress through the following lifecycle.

```text
Created
    ↓
Funded
    ↓
Locked
    ↓
Submitted (optional)
    ↓
Released
        or
Refunded
        or
Expired
```

Implementations MAY introduce intermediate states.

They SHALL NOT alter lifecycle semantics.

---

# Participants

Escrow MAY include:

* payer
* recipient
* evaluator
* arbitrator
* treasury
* automated protocol logic

The protocol does not require all participant roles.

---

# Funding

Funding SHALL transfer value into escrow custody.

Funding SHALL NOT constitute settlement.

Ownership remains conditional until settlement.

---

# Locking

Locked assets SHALL NOT be transferred outside escrow except through protocol-defined transitions.

---

# Release

Release SHALL transfer escrowed value to its designated recipient.

Release SHALL complete settlement.

Release SHALL be irreversible.

---

# Refund

Refund SHALL return escrowed value to the originating owner.

Refund SHALL terminate the obligation.

---

# Expiration

Escrow MAY define expiration conditions.

Expired escrows SHALL resolve deterministically.

Resolution MAY result in:

* refund
* cancellation
* governance-defined behavior

---

# Arbitration

The protocol permits external arbitration.

However:

Arbitration is not escrow.

Escrow SHALL remain independent of any arbitration implementation.

Arbitrators influence release decisions.

They do not redefine escrow semantics.

---

# Determinism

Equivalent escrow inputs SHALL produce equivalent protocol outcomes.

Escrow evaluation SHALL remain deterministic.

---

# Compliance

Implementations SHALL:

* preserve escrow invariants
* prevent unauthorized release
* prevent unauthorized refund
* preserve value conservation
* maintain complete auditability

---

# Security Considerations

Escrow SHALL resist:

* double settlement
* premature release
* unauthorized cancellation
* replay attacks
* value duplication

Escrow SHALL maintain conservation of value throughout every lifecycle transition.

---

# References

Book X — Economic Model

APS-200 Monetary Layer Standard

APS-201 Settlement Standard

RFC Escrow Object

Protocol Specification

---

# Amendment

Changes require governance approval.
