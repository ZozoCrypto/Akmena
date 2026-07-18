# RFC-304

# Delegation Object

RFC Version: 1.0

Status: Draft

Layer: Coordination

Canonical Identifier:

akmena.delegation

Normative: Yes

Depends On:

RFC-001 Identity

RFC-301 Organization

Required By:

APS-404 Delegation Standard

---

# 1 Purpose

This RFC defines the canonical Delegation object.

Delegation allows a Participant to temporarily authorize another Participant to act within a defined scope.

---

# 2 Canonical Definition

A Delegation is an explicit, revocable transfer of limited authority from one Participant to another.

---

# 3 Object Invariants

* Delegation SHALL identify a delegator.
* Delegation SHALL identify a delegate.
* Delegation SHALL define scope.
* Delegation SHALL be revocable.
* Delegation SHALL remain auditable.

---

# 4 Required Fields

* identifier
* delegator
* delegate
* scope
* issuedAt
* status

---

# 5 Optional Fields

* expiresAt
* metadata

---

# 6 Lifecycle

Created

↓

Granted

↓

Active

↓

Revoked

OR

Expired

↓

Archived

---

# 7 Validation Rules

Delegation scope SHALL remain explicit.

Expired Delegations SHALL NOT grant authority.

---

# 8 Security Considerations

Delegations SHALL require valid Authorization.

Revocation SHALL take effect immediately.

---

# 9 References

APS-404

RFC-301

Protocol Invariants

---

# 10 Compliance

Implementations SHALL preserve Delegation semantics.
