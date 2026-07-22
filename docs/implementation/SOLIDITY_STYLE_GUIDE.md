# Solidity Style Guide

**Protocol:** Akmena Autonomous Economic Protocol (AEP)

**Implementation:** V2

**Status:** Engineering Constitution

---

# 1. Purpose

This document defines mandatory Solidity coding standards for every Akmena smart contract.

Consistency is a protocol requirement.

---

# 2. Compiler

All contracts SHALL use the same compiler version unless an Architecture Decision Record specifies otherwise.

Example:

pragma solidity ^0.8.28;

---

# 3. File Header

Every Solidity file SHALL begin with:

* SPDX License
* Compiler Version
* Protocol Version
* Module Name
* Book
* APS
* RFC
* ADR
* Authoritative Module

Example

Implements:

Book IV

APS-202

RFC-103

ADR-011

Economics Domain

Escrow Module

---

# 4. Naming

Contracts

PascalCase

IdentityFactory

Escrow

Treasury

Interfaces

Prefix I

IIdentity

IEscrow

Libraries

Prefix Lib

LibIdentity

LibEconomics

Storage

Suffix Storage

IdentityStorage

TrustStorage

---

# 5. Functions

External

first

Public

second

Internal

third

Private

last

View functions SHALL appear before state-changing functions.

---

# 6. Events

Events SHALL use completed actions.

Correct

AgreementCreated

SettlementCompleted

MemoryRecorded

Incorrect

CreateAgreement

DoSettlement

---

# 7. Errors

Custom errors SHALL be preferred over string reverts.

Correct

error Unauthorized();

Incorrect

require(x, "Unauthorized");

---

# 8. Constants

UPPER_CASE

MAX_SUPPLY

SECONDS_PER_DAY

---

# 9. Comments

Explain why.

Do not explain obvious syntax.

---

# 10. Storage

Storage SHALL only exist inside the owning module.

Cross-module storage access is prohibited.

---

# 11. Imports

Imports SHALL remain deterministic.

Wildcard imports are prohibited.

---

# 12. Security

Every external function SHALL explicitly consider:

authorization

reentrancy

overflow

storage mutation

event emission

---

# 13. Testing

Every public function SHALL possess unit tests.

---

# 14. Invariants

Readable.

Deterministic.

Auditable.

Modular.

Upgradeable only where permitted.

---

## End
