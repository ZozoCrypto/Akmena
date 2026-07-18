# RFC-302

# Proposal Object

RFC Version: 1.0

Status: Draft

Layer: Coordination

Canonical Identifier:

akmena.proposal

Normative: Yes

Depends On:

RFC-001 Identity

RFC-301 Organization

Required By:

RFC-303 Vote

APS-402 Proposal Standard

---

# 1 Purpose

This RFC defines the canonical Proposal object.

A Proposal is a structured request for collective consideration and decision.

---

# 2 Canonical Definition

A Proposal describes an explicit action, policy, or change submitted to an Organization for evaluation.

---

# 3 Object Invariants

* Every Proposal SHALL identify its proposer.
* Every Proposal SHALL identify its target Organization.
* Proposal contents SHALL remain immutable after submission.
* Proposal outcomes SHALL remain auditable.

---

# 4 Required Fields

* identifier
* proposer
* organization
* title
* descriptionReference
* status

---

# 5 Lifecycle

Draft

↓

Submitted

↓

Active

↓

Approved

OR

Rejected

OR

Expired

↓

Archived

---

# 6 Validation Rules

Submitted Proposals SHALL become immutable.

---

# 7 References

APS-402

RFC-301

Protocol Invariants
