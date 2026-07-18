# ADR-009

# Diamond Architecture

Status: Accepted

Decision Type: Implementation Architecture

---

# Context

The protocol requires modular evolution while preserving stable contract addresses and storage.

---

# Decision

The reference Solidity implementation adopts the Diamond (EIP-2535) architecture.

This is an implementation decision, not a protocol requirement.

Alternative implementations may use different architectures while preserving protocol behavior.

---

# Rationale

The Diamond architecture provides modular upgrades, isolated facets, and long-term maintainability without altering the protocol specification.

---

# Consequences

Positive

* modular implementation
* upgrade flexibility
* reusable facets

Negative

* increased implementation complexity

---

# References

Reference Implementation

Book II

Protocol Invariants
