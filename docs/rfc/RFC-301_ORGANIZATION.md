# RFC-301

# Organization Object

RFC Version: 1.0

Status: Draft

Layer: Coordination

Canonical Identifier:

akmena.organization

Normative: Yes

Depends On:

RFC-001 Identity

RFC-005 Participant

Required By:

RFC-302 Proposal

RFC-304 Delegation

APS-400 Coordination Standard

APS-507 Organization Interaction Standard

---

# 1 Purpose

This RFC defines the canonical Organization object.

An Organization is a coordinated collection of Participants operating under shared protocol rules.

Organizations are Participants.

Organizations do not possess implicit protocol privilege.

---

# 2 Scope

Defines:

* organization semantics

* membership

* coordination relationships

* lifecycle

* validation

---

# 3 Canonical Definition

An Organization is a protocol Participant composed of one or more member Participants and governed by explicit coordination rules.

---

# 4 Object Invariants

* Every Organization SHALL possess exactly one Identity.
* Every Organization SHALL be a Participant.
* Membership SHALL be explicit.
* Authority SHALL be explicit.
* Organizations SHALL remain auditable.

---

# 5 Object Model

Contains:

* Organization Identifier
* Identity Reference
* Member References
* Coordination Rules
* Status

---

# 6 Required Fields

* identifier
* identity
* members
* status

---

# 7 Optional Fields

* metadata
* treasuryReference
* governancePolicyReference

---

# 8 Relationships

Organizations MAY reference:

* Participants
* Proposals
* Delegations
* Treasury
* Agreements

---

# 9 Lifecycle

Created

↓

Active

↓

Suspended

↓

Archived

---

# 10 Validation Rules

Member references SHALL resolve to valid Participants.

Archived Organizations SHALL remain resolvable.

---

# 11 Security Considerations

Membership changes SHALL require Authorization.

Organization authority SHALL remain explicitly defined.

---

# 12 Compatibility

Organizations SHALL remain implementation independent.

---

# 13 References

APS-400

APS-507

RFC-001

RFC-005

Protocol Invariants

---

# 14 Compliance

Implementations SHALL preserve Organization semantics.
