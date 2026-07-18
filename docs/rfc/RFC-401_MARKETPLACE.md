# RFC-401

# Marketplace Object

RFC Version: 1.0

Status: Draft

Layer: Autonomous Economy

Canonical Identifier:

akmena.marketplace

Normative: Yes

Depends On:

RFC-001 Identity

RFC-002 Agent

RFC-005 Participant

RFC-101 Asset

RFC-201 Reputation

Required By:

RFC-402 Agreement

APS-501 Marketplace Standard

---

# Purpose

Defines the canonical Marketplace object.

The Marketplace enables Participants to discover, advertise, negotiate, and exchange value through protocol-defined interactions.

---

# Canonical Definition

A Marketplace is a protocol environment that facilitates voluntary economic interaction among Participants.

The Marketplace does not execute agreements.

It enables their formation.

---

# Object Invariants

* Marketplaces SHALL remain open to authorized Participants.
* Marketplaces SHALL NOT modify Settlement.
* Marketplaces SHALL preserve historical records.
* Marketplaces SHALL remain implementation independent.

---

# Required Fields

* identifier
* participants
* listings
* status

---

# Relationships

Marketplace MAY reference:

* Participants
* Services
* Skills
* Agreements
* Reputation

---

# References

APS-501

Book XI

Protocol Invariants
