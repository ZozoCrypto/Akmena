# RFC-402

# Agreement Object

RFC Version: 1.0

Status: Draft

Layer: Autonomous Economy

Canonical Identifier:

akmena.agreement

Normative: Yes

Depends On:

RFC-103 Escrow

RFC-104 Settlement

RFC-301 Organization

Required By:

RFC-404 Service

APS-502 Agreement Standard

---

# Purpose

Defines the canonical Agreement object.

Agreements formalize obligations between Participants.

---

# Canonical Definition

An Agreement records mutually accepted protocol obligations.

Execution occurs separately.

Settlement completes obligations.

---

# Object Invariants

* Agreements SHALL preserve participant intent.
* Agreements SHALL remain immutable after acceptance.
* Agreements SHALL reference explicit obligations.
* Agreements SHALL remain independently verifiable.

---

# Required Fields

* identifier
* parties
* obligations
* status

---

# Lifecycle

Draft

↓

Negotiated

↓

Accepted

↓

Executed

↓

Settled

↓

Archived

---

# References

APS-502

Book XI
