# RFC-202

# Verification Object

RFC Version: 1.0

Status: Draft

Layer: Trust

Canonical Identifier:

akmena.verification

Normative: Yes

Depends On:

RFC-001 Identity

Required By:

RFC-203 Attestation

APS-302 Verification Standard

---

# 1 Purpose

Verification represents objective confirmation that a protocol claim satisfies defined requirements.

Verification establishes evidence.

It does not establish trust.

---

# 2 Canonical Definition

Verification records successful validation of a claim according to protocol-defined criteria.

---

# 3 Object Invariants

* Verification SHALL remain objective.
* Verification SHALL reference verifiable evidence.
* Verification SHALL NOT imply trust.
* Verification SHALL remain auditable.

---

# 4 Required Fields

* identifier
* subject
* verifier
* evidenceReference
* timestamp
* status

---

# 5 Relationships

Verification MAY reference:

* Identity
* Attestation
* Capability
* Agreement

---

# 6 Lifecycle

Requested

↓

Verified

↓

Expired

↓

Archived

---

# 7 Validation Rules

Evidence SHALL remain independently verifiable.

---

# 8 Security

Verification SHALL preserve evidence integrity.

---

# 9 References

APS-302

Protocol Invariants

---

# 10 Compliance

Implementations SHALL preserve Verification semantics.
