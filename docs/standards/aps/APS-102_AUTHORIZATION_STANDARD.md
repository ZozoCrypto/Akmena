# APS-102

# Authorization Standard

Version: 1.0

Status: Draft

Category: Identity & Coordination

Authority: Protocol Standard

---

# Purpose

This standard defines protocol authorization.

Authorization determines who may perform protocol actions.

---

# Scope

This standard governs:

* Permissions
* Controllers
* Delegation
* Capability assignment
* Authorization evaluation

---

# Normative Requirements

Authorization SHALL be evaluated before protected protocol actions.

Authorization SHALL be independent of identity persistence.

Authorization SHALL support delegation.

Authorization SHALL support revocation.

Authorization SHALL support multiple authorization models.

Authorization SHALL NOT require ownership transfer.

---

# Authorization Model

Authorization consists of:

Identity

↓

Controller

↓

Capability

↓

Permission

↓

Action

---

# Delegation

Permissions MAY be delegated.

Delegated permissions SHALL be revocable.

Delegation SHALL NOT permanently alter ownership.

---

# Revocation

Revocation SHALL immediately invalidate future authorization decisions.

Historical protocol records SHALL remain unchanged.

---

# References

APS-100

APS-101

RFC Authorization Object

Protocol Specification Book III

---

# Security Considerations

Authorization SHALL follow least-privilege principles.

Authorization SHALL resist privilege escalation.

Authorization SHALL support deterministic evaluation.

---

# Amendment

Changes require governance approval.
