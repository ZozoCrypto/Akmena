# APS-404

# Delegation Standard

Version: 1.0

Status: Draft

Category: Coordination Layer

Authority: Protocol Standard

Classification: Normative

---

# Purpose

Defines delegation within the Akmena Protocol.

Delegation permits one participant to authorize another participant to act on its behalf under explicitly defined constraints.

Delegation transfers authority.

Delegation does not transfer ownership.

---

# Scope

This standard governs:

* delegated authority
* delegation lifecycle
* delegation constraints
* revocation
* expiration

---

# Delegation Principles

Delegation SHALL be:

* explicit
* revocable
* auditable
* deterministic
* permission-scoped

---

# Delegation Lifecycle

Created

↓

Active

↓

Modified

↓

Revoked

or

Expired

---

# Normative Requirements

Delegation SHALL identify:

* delegator
* delegate
* authority scope
* expiration conditions

Delegation SHALL remain independently revocable.

Delegation SHALL NOT modify ownership.

Delegation SHALL preserve historical audit records.

---

# Compliance

Implementations SHALL preserve deterministic delegation evaluation.

---

# Security Considerations

Delegation escalation SHALL be prevented.

Revoked delegations SHALL immediately cease authorizing future actions.

---

# References

APS-103 Capability Standard

APS-401 Governance Interface Standard

RFC Delegation Object

Book II

---

# Amendment

Changes require governance approval.
