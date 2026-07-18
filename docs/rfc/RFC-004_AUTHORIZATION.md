# RFC-004

# Authorization Object

RFC Version: 1.0

Status: Draft

Layer: Identity

Canonical Identifier:

akmena.authorization

Normative: Yes

Depends On:

RFC-001 Identity

Required By:

RFC-002 Agent

RFC-005 Participant

APS-103 Authorization Standard

---

# Purpose

Authorization defines explicit protocol permission.

Authorization grants the ability to perform protocol actions.

Authorization SHALL NOT imply trust.

Authorization SHALL NOT imply capability.

---

# Object Invariants

* Authorization SHALL be explicit.
* Authorization SHALL be revocable.
* Authorization SHALL possess scope.
* Authorization SHALL possess an issuer.
* Authorization SHALL remain auditable.

---

# Required Fields

* identifier
* issuer
* subject
* scope
* issuedAt

---

# Lifecycle

Created

↓

Granted

↓

Active

↓

Revoked

↓

Expired

---

# References

RFC-001

APS-103

ADR-004

Protocol Invariants
