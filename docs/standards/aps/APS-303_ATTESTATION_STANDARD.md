# APS-303

# Attestation Standard

Version: 1.0

Status: Draft

Category: Trust Layer

Authority: Protocol Standard

Classification: Normative

---

# Purpose

This standard defines attestations.

An attestation is a protocol-recognized assertion made by an issuer regarding another protocol object.

Attestations are evidence.

They are not proof of truth.

---

# Scope

This standard governs:

* attestation creation
* issuers
* subjects
* validity
* revocation

---

# Attestation Model

Every attestation contains:

Issuer

↓

Subject

↓

Claim

↓

Evidence

↓

Validity

---

# Normative Requirements

Attestations SHALL identify an issuer.

Attestations SHALL identify a subject.

Attestations SHALL support revocation.

Attestations SHALL remain independently verifiable.

Attestations SHALL NOT automatically modify reputation.

---

# Compliance

Implementations SHALL preserve attestation integrity.

---

# Security Considerations

Attestation forgery SHALL be detectable.

Revocation SHALL remain publicly verifiable.

---

# References

APS-300

APS-302

RFC Attestation Object

Book II

---

# Amendment

Changes require governance approval.
