# ADR-002

# Dependency Direction

Status: Accepted

Decision Type: Foundational

---

# Decision

Dependencies SHALL always point downward.

Higher layers consume lower layers.

Lower layers SHALL NEVER reference higher layers.

---

# Rationale

One-way dependencies eliminate architectural cycles and preserve protocol stability.

---

# Consequences

Improved modularity

Simplified auditing

Predictable evolution

---

# References

ADR-001

Protocol Invariants
