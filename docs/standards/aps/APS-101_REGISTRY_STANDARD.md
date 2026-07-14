# APS-101

# Registry Standard

Version: 1.0

Status: Draft

Category: Identity & Coordination

Authority: Protocol Standard

---

# Purpose

This standard defines the canonical registry responsible for discovering protocol identities and objects.

---

# Scope

The registry standard governs:

* Identity registration
* Object discovery
* Canonical references
* Resolution

---

# Normative Requirements

The registry SHALL assign globally unique identifiers.

Registry entries SHALL remain immutable once published except where explicitly permitted.

The registry SHALL support deterministic lookup.

The registry SHALL be implementation independent.

The registry SHALL NOT define trust or reputation.

---

# Registry Objects

The registry MAY contain:

* Identities
* Organizations
* Capabilities
* Credentials
* Agreements
* Agents

Additional object types MAY be introduced through future standards.

---

# Resolution

Every registry identifier SHALL resolve deterministically.

---

# References

APS-100

APS-102

RFC Registry Object

Protocol Specification Book III

---

# Security Considerations

Registry integrity SHALL be verifiable.

Registry identifiers SHALL remain collision resistant.

Registry SHALL prevent duplicate canonical identities.

---

# Amendment

Changes require governance approval.
