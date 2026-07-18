# RFC-303

# Vote Object

RFC Version: 1.0

Status: Draft

Layer: Coordination

Canonical Identifier:

akmena.vote

Normative: Yes

Depends On:

RFC-001 Identity

RFC-302 Proposal

Required By:

APS-403 Voting Standard

---

# 1 Purpose

This RFC defines the canonical Vote object.

A Vote records a Participant's decision regarding a Proposal.

---

# 2 Canonical Definition

A Vote is an immutable record of a voting decision associated with a specific Proposal.

---

# 3 Object Invariants

* Every Vote SHALL reference exactly one Proposal.
* Every Vote SHALL identify exactly one voter.
* Submitted Votes SHALL remain immutable.
* Vote records SHALL remain auditable.

---

# 4 Required Fields

* identifier
* proposalReference
* voter
* choice
* timestamp
* status

---

# 5 Lifecycle

Created

↓

Submitted

↓

Counted

↓

Archived

---

# 6 Validation Rules

Vote references SHALL resolve to valid Proposals.

---

# 7 References

APS-403

RFC-302

Protocol Invariants
