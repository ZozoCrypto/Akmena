# RFC-102

# Treasury Object

RFC Version: 1.0

Status: Draft

Layer: Economic

Canonical Identifier:

akmena.treasury

Normative: Yes

Depends On:

RFC-001

RFC-101

Required By:

RFC-103

RFC-104

APS-203 Treasury Standard

---

# Purpose

Treasury represents managed protocol-controlled assets.

---

# Canonical Definition

A Treasury is an Asset container governed by explicit protocol rules.

---

# Object Invariants

* Treasury SHALL contain Assets.
* Treasury SHALL preserve accounting integrity.
* Treasury SHALL remain auditable.
* Treasury SHALL never create value.

---

# Required Fields

* identifier
* owner
* assetCollection
* status

---

# Relationships

Treasury MAY reference:

* Organizations
* Assets
* Settlements
* Escrow

---

# Lifecycle

Created

↓

Active

↓

Managed

↓

Archived

---

# Validation

Balances SHALL remain internally consistent.

---

# References

APS-203

RFC-101

Protocol Invariants
