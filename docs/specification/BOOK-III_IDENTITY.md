# BOOK III

# Identity

**Protocol Version:** 1.0

**Status:** Constitutional Specification

**Layer:** Identity

**Normative:** Yes

---

# 1. Purpose

This Book defines the Identity Layer of the Akmena Protocol.

Identity provides the foundation upon which every other protocol layer depends.

No protocol operation SHALL occur without a valid protocol participant.

---

# 2. Scope

This Book defines:

* Participants
* Identity
* Agents
* Organizations
* Capabilities
* Authorization
* Identity relationships

This Book does not define implementation mechanisms.

Those belong to APS and RFC documents.

---

# 3. Identity Layer

The Identity Layer is the foundational protocol layer.

Every higher layer SHALL depend upon Identity.

Identity SHALL depend upon no higher layer.

---

# 4. Participants

A Participant is any entity capable of interacting with the protocol.

Participants MAY include:

* Humans
* Organizations
* Autonomous AI Agents
* Software Systems
* Future protocol participant classes

The protocol SHALL treat all Participants according to protocol behavior rather than implementation.

---

# 5. Identity

Identity uniquely represents a Participant within the protocol.

Identity SHALL remain persistent.

Identity SHALL remain globally unique within a protocol instance.

Identity SHALL NOT imply authority.

Identity SHALL NOT imply trust.

Identity SHALL NOT imply ownership.

Identity is identification only.

---

# 6. Agents

An Agent is a Participant capable of autonomous protocol interaction.

Agents MAY:

* own Assets
* execute Services
* enter Agreements
* publish Skills
* accumulate Reputation
* participate in Governance

Agents SHALL remain Participants.

---

# 7. Organizations

Organizations represent coordinated groups of Participants.

Organizations SHALL possess protocol Identity.

Organizations MAY own Assets.

Organizations MAY publish Services.

Organizations MAY participate in Governance.

Organizations SHALL remain Participants.

---

# 8. Capabilities

Capabilities describe actions a Participant is technically able to perform.

Capabilities SHALL NOT grant permission.

Capabilities SHALL remain descriptive.

Authorization determines whether a Capability may be exercised.

---

# 9. Authorization

Authorization grants explicit permission for protocol actions.

Authorization SHALL always be:

* explicit
* auditable
* revocable
* deterministic

Authorization SHALL NEVER be inferred from:

* Identity
* Reputation
* Verification
* Ownership
* Organization membership

---

# 10. Identity Relationships

Participants MAY establish relationships with:

* Assets
* Organizations
* Agreements
* Services
* Skills
* Reputation
* Verification
* Attestations

Relationships SHALL remain explicit.

---

# 11. Identity Invariants

The following SHALL remain true:

* Every protocol participant possesses Identity.
* Identity precedes authorization.
* Identity does not imply trust.
* Identity does not imply ownership.
* Identity remains implementation independent.
* Authorization remains explicit.

---

# 12. Security

Identity SHALL provide the minimum information necessary for protocol interaction.

Implementations MAY extend identity information provided protocol behavior remains unchanged.

---

# 13. Extensibility

Future protocol versions MAY introduce new Participant types.

Existing Identity semantics SHALL remain preserved.

---

# 14. References

Book I — Foundations

Book II — Architecture

APS-100 Identity Standards

RFC-001 Identity

RFC-002 Agent

RFC-003 Capability

RFC-004 Authorization

RFC-005 Participant

Protocol Invariants

---

## End of Book III
