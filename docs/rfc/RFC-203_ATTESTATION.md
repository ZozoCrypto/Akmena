# RFC-203

# Attestation Object

RFC Version: 1.0

Status: Draft

Layer: Trust

Canonical Identifier:

akmena.attestation

Normative: Yes

Depends On:

RFC-001 Identity

RFC-202 Verification

Required By:

RFC-201 Reputation

APS-303 Attestation Standard

---

# 1 Purpose

This RFC defines the canonical Attestation object.

Attestations communicate statements made by Participants regarding protocol observations.

Attestations are assertions.

They are not protocol truth.

---

# 2 Canonical Definition

An Attestation is a signed protocol statement referencing one or more verifiable facts.

Participants evaluate the credibility of Attestations independently.

---

# 3 Object Invariants

* Attestations SHALL identify their issuer.
* Attestations SHALL reference verifiable subjects.
* Attestations SHALL remain immutable after publication.
* Attestations SHALL NOT automatically alter Reputation.

---

# 4 Required Fields

* identifier
* issuer
* subject
* statementReference
* timestamp
* status

---

# 5 Relationships

Attestations MAY reference:

* Identity
* Verification
* Reputation
* Agreement

---

# 6 Lifecycle

Draft

↓

Published

↓

Referenced

↓

Archived

---

# 7 Validation Rules

Published Attestations SHALL retain their original contents.

---

# 8 Security Considerations

Issuer authenticity SHALL remain verifiable.

---

# 9 Compatibility

Attestations SHALL remain implementation independent.

---

# 10 References

APS-303

RFC-202

Protocol Invariants

---

# 11 Compliance

Implementations SHALL preserve Attestation semantics.
