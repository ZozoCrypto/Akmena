# RFC-005

# Participant Object

RFC Version: 1.0

Status: Draft

Layer: Identity

Canonical Identifier:

akmena.participant

Normative: Yes

Depends On:

RFC-001

RFC-003

RFC-004

Required By:

RFC-002 Agent

RFC-301 Organization

---

# Purpose

Participant is the abstract protocol entity capable of interacting with the Akmena Protocol.

Every concrete protocol actor SHALL be a Participant.

---

# Participant Types

Examples include:

* Human
* AI Agent
* Organization
* Service

Future participant types MAY be introduced without modifying this RFC.

---

# Required Fields

* identity
* capabilities
* authorizations
* status

---

# Relationships

Participants SHALL reference exactly one Identity.

Participants MAY reference multiple Capabilities.

Participants MAY reference multiple Authorizations.

---

# References

RFC-001

RFC-003

RFC-004

APS-500

Protocol Invariants
