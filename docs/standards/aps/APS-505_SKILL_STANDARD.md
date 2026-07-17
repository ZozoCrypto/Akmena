# APS-505

# Skill Standard

Version: 1.0

Status: Draft

Category: Autonomous Economy Layer

Authority: Protocol Standard

Classification: Normative

---

# Purpose

This standard defines reusable protocol skills.

A skill represents a capability that may be advertised, discovered, invoked, and reused by protocol participants.

Skills describe capability.

They do not imply trust.

---

# Scope

This standard governs:

* skill definitions
* skill publication
* skill discovery
* skill invocation
* skill lifecycle

---

# Skill Principles

Skills SHALL be:

reusable

discoverable

versionable

implementation independent

identity associated

---

# Skill Metadata

Every skill SHALL define:

identifier

owner

version

capability description

supported interfaces

---

# Skill Lifecycle

Draft

↓

Published

↓

Discoverable

↓

Invokable

↓

Deprecated

↓

Archived

---

# Normative Requirements

Skills SHALL possess unique identifiers.

Skills SHALL remain independently discoverable.

Skill invocation SHALL remain separate from skill definition.

Skills SHALL support versioning.

---

# Compliance

Implementations SHALL preserve skill interoperability.

---

# Security Considerations

Skill publication SHALL require authorization.

Skill invocation SHALL respect protocol permissions.

---

# References

APS-503

APS-506

RFC Skill Object

Book XI

---

# Amendment

Changes require governance approval.
