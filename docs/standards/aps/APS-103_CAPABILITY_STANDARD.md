# APS-103

# Capability Standard

Version: 1.0

Status: Draft

Category: Identity & Coordination

Authority: Protocol Standard

---

# Purpose

This standard defines protocol capabilities.

Capabilities describe what an identity is permitted to perform within the Akmena Protocol.

Capabilities are protocol primitives.

They are independent from ownership, credentials, reputation, and implementation.

---

# Scope

This standard governs:

* Capability definitions
* Capability assignment
* Capability delegation
* Capability revocation
* Capability evaluation

---

# Terminology

Capability

A protocol-defined permission representing the ability to perform one or more actions.

Permission

A protocol rule granting execution of a specific action.

Controller

The entity authorized to assign capabilities.

---

# Normative Requirements

Capabilities SHALL be explicitly assigned.

Capabilities SHALL be independently revocable.

Capabilities SHALL support delegation.

Capabilities SHALL support expiration.

Capabilities SHALL NOT imply ownership.

Capabilities SHALL NOT permanently alter identity.

---

# Delegation

Delegated capabilities SHALL reference the originating authority.

Delegation SHALL be revocable.

Delegation SHALL preserve auditability.

---

# Revocation

Revoked capabilities SHALL immediately cease authorizing future actions.

Historical records SHALL remain immutable.

---

# Compliance

Implementations SHALL evaluate capabilities deterministically.

---

# Security Considerations

Capability escalation SHALL be prevented.

Capabilities SHALL follow least-privilege principles.

---

# References

APS-100

APS-101

APS-102

RFC Capability Object

Protocol Specification Book III

---

# Amendment

Changes require governance approval.
