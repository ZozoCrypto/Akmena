# Akmena Protocol V2 Deployment Registry

**Version:** v2.0.0-rc.1

**Network:** Base Sepolia

This document records the canonical deployment addresses for the Akmena Protocol Release Candidate.

---

# Deployment Status

| Component        | Status            |
| ---------------- | ----------------- |
| Protocol Version | v2.0.0-rc.1       |
| Network          | Base Sepolia      |
| Deployment       | Complete          |
| Verification     | Complete          |
| Release Status   | Release Candidate |

---

# Core Contracts

## AkmenaCore

**Address**

```
0x48220ad958fd47466cFcb9B79ceC6994C55e2604
```

**Responsibilities**

* Protocol router
* Module registry
* Module discovery
* Upgrade coordination
* Canonical protocol entry point

---

## EscrowEngine

**Address**

```
0x7A3C240a3FfB054d1C588355C928Ed9118A18c63
```

**Responsibilities**

* Escrow creation
* Fund custody
* Settlement authorization
* Payment release

---

## AgentRegistry

**Address**

```
0x940b6260Df7eBD78CB6484791F4B4f2Ccf9109D2
```

**Responsibilities**

* Identity registration
* Identity discovery
* Registry resolution
* Protocol participant directory

---

# Verification

All Release Candidate contracts have been verified on Base Sepolia.

The verified source code exactly matches the deployed bytecode.

---

# Deployment Principles

Deployments follow the Akmena Engineering Constitution.

Specifically:

* deterministic deployment procedures
* immutable protocol architecture
* reproducible deployments
* documented verification
* no manual post-deployment mutation

---

# Upgrade Authority

Protocol upgrades are governed exclusively through the Governance system.

Direct deployer control is removed after governance activation.

Future upgrades SHALL proceed through:

Governor

↓

Timelock

↓

Execution

---

# Network Configuration

**Chain**

Base Sepolia

**Purpose**

Public integration testing

Developer onboarding

SDK validation

Protocol verification

Grant demonstrations

---

# Release History

| Version               | Status      |
| --------------------- | ----------- |
| v2-sprint7-governance | Complete    |
| v2-sprint8-runtime    | Complete    |
| v2-sprint9-sdk        | In Progress |
| v2.0.0-rc.1           | Current     |

---

# Future Deployments

Production deployments will be documented in this registry using the same format.

Historical deployment records SHALL remain immutable.

Superseded deployments SHALL NOT be deleted.

---

# Engineering Note

This document serves as the canonical deployment registry for Akmena Protocol V2 and is intended for:

* ecosystem reviewers
* auditors
* grant reviewers
* infrastructure providers
* developers
* protocol operators

Any future deployment SHALL update this document as part of the Release Definition of Done.
