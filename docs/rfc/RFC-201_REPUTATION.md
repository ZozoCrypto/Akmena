# RFC-201

# Reputation Object

RFC Version: 1.0

Status: Draft

Layer: Trust

Canonical Identifier:

akmena.reputation

Normative: Yes

Depends On:

RFC-001 Identity

RFC-005 Participant

Required By:

RFC-301 Organization

RFC-401 Marketplace

APS-300 Reputation Standard

---

# 1 Purpose

This RFC defines the canonical Reputation object.

Reputation records historical protocol observations associated with a Participant.

Reputation is descriptive.

Reputation is not authority.

---

# 2 Scope

Defines:

* reputation semantics
* lifecycle
* relationships
* validation
* compatibility

---

# 3 Canonical Definition

Reputation represents accumulated protocol history derived from completed interactions.

It reflects observable behavior.

It SHALL NOT directly grant permissions or protocol authority.

---

# 4 Object Invariants

* Reputation SHALL reference completed protocol events.
* Reputation SHALL remain append-only.
* Reputation SHALL NOT modify historical records.
* Reputation SHALL NOT imply trust.
* Reputation SHALL NOT imply authorization.

---

# 5 Object Model

Contains:

* Reputation Identifier
* Subject Identity
* Event References
* Timestamp
* Status

---

# 6 Required Fields

* identifier
* subject
* eventReferences
* status

---

# 7 Optional Fields

* metadata
* summaries
* externalReferences

---

# 8 Relationships

Reputation MAY reference:

* Identity
* Attestation
* Verification
* Settlement
* Agreement

---

# 9 Lifecycle

Created

↓

Active

↓

Archived

Reputation SHALL NOT be deleted.

---

# 10 Validation Rules

Referenced events SHALL exist.

Historical ordering SHALL remain preserved.

---

# 11 Security Considerations

Reputation SHALL remain resistant to unauthorized modification.

---

# 12 Compatibility

Reputation SHALL remain implementation independent.

---

# 13 References

APS-300

Protocol Invariants

ADR-004

---

# 14 Compliance

Implementations SHALL preserve Reputation semantics.
