# RFC-003

# Capability Object

RFC Version: 1.0

Status: Draft

Layer: Identity

Canonical Identifier:

akmena.capability

Normative: Yes

Depends On:

RFC-001 Identity

Required By:

RFC-002 Agent

RFC-005 Participant

APS-505 Skill Standard

---

# 1 Purpose

This RFC defines the canonical Capability object.

A Capability represents a reusable description of what a participant is able to perform.

Capabilities describe potential.

They do not imply authorization, trust, or execution.

---

# 2 Scope

This RFC defines:

* capability semantics
* capability metadata
* lifecycle
* relationships
* validation
* compatibility

---

# 3 Canonical Definition

A Capability is a protocol-recognized description of a reusable function, competency, or behavior that may be associated with an Identity.

Capabilities are descriptive objects.

They are not executable objects.

---

# 4 Object Invariants

* Capability identifiers SHALL be unique.
* Capabilities SHALL be reusable.
* Capabilities SHALL be implementation independent.
* Capabilities SHALL NOT imply authorization.
* Capabilities SHALL NOT imply trust.

---

# 5 Object Model

Capability contains:

* Capability Identifier
* Version
* Status
* Owner Identity
* Description
* Metadata References

---

# 6 Required Fields

* identifier
* version
* ownerIdentity
* status
* description

---

# 7 Optional Fields

* metadata
* tags
* interfaces
* externalReferences

---

# 8 Relationships

Capabilities MAY reference:

* Identity
* Skills
* Services
* Participants

Capabilities SHALL NOT reference Authorization.

---

# 9 Lifecycle

Draft

↓

Published

↓

Active

↓

Deprecated

↓

Archived

---

# 10 Validation Rules

Capability identifiers SHALL remain unique.

Published capabilities SHALL possess an owner.

Archived capabilities SHALL remain resolvable.

---

# 11 Security Considerations

Capability publication SHALL require authorization.

Capability existence SHALL NOT imply permission.

---

# 12 Compatibility

Capabilities SHALL remain portable across implementations.

---

# 13 References

RFC-001

APS-505

Protocol Invariants

---

# 14 Compliance

Implementations SHALL preserve Capability semantics.
