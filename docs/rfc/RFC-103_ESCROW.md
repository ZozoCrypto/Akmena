# RFC-103

# Escrow Object

RFC Version: 1.0

Status: Draft

Layer: Economic

Canonical Identifier:

akmena.escrow

Normative: Yes

Depends On:

RFC-101

RFC-102

Required By:

RFC-104

APS-202 Escrow Standard

---

# Purpose

Escrow represents conditional custody of Assets pending protocol-defined conditions.

---

# Canonical Definition

Escrow temporarily restricts Asset transfer until release conditions are satisfied.

Escrow is conditional settlement.

---

# Object Invariants

* Escrow SHALL never create Assets.
* Escrow SHALL never destroy Assets.
* Escrow SHALL define explicit release conditions.
* Escrow SHALL preserve ownership history.

---

# Required Fields

* identifier
* assetReference
* depositor
* beneficiary
* conditions
* status

---

# Lifecycle

Created

↓

Funded

↓

Locked

↓

Released

OR

Refunded

↓

Closed

---

# Validation

Escrow SHALL reference valid Assets.

---

# References

APS-202

RFC-101

RFC-102

Protocol Invariants
