# Protocol State Machine

**Classification:** Formal

This document defines the canonical state machine of the Akmena Protocol.

---

# Global Lifecycle

Participant Created
↓
Identity Authorized
↓
Capability Granted
↓
Economic Participation
↓
Trust Evidence Generated
↓
Coordination Participation
↓
Autonomous Economic Execution
↓
Historical Memory

---

# Identity State Machine

Created
↓
Authorized
↓
Capability Granted
↓
Active
↓
Suspended
↓
Reactivated

---

# Agreement State Machine

Draft
↓
Published
↓
Accepted
↓
Escrow Locked
↓
Service Executing
↓
Settlement Pending
↓
Completed

Alternative terminal states:

Cancelled
Expired
Disputed

---

# Governance State Machine

Proposal Created
↓
Review
↓
Voting Open
↓
Voting Closed
↓
Consensus Determined
↓
Executed

Alternative terminal state:

Rejected

---

# Memory State Machine

Interaction Completed
↓
Evidence Generated
↓
Memory Recorded
↓
Indexed
↓
Searchable
↓
Permanent Historical Record

---

# Terminal Guarantees

Completed
Cancelled
Expired
Rejected
Disputed

Terminal states SHALL be immutable.
...
...
# Additional State Machines

---

# Identity Lifecycle

```text
Unregistered
      │
      ▼
Registered
      │
      ▼
Verified
      │
      ▼
Authorized
      │
      ▼
Capability Granted
      │
      ▼
Marketplace Eligible
      │
      ▼
Active
      │
      ▼
Suspended
      │
      ▼
Retired
```

---

# Capability Lifecycle

```text
Defined
    │
    ▼
Published
    │
    ▼
Granted
    │
    ▼
Exercised
    │
    ▼
Revoked
```

---

# Agreement Lifecycle

```text
Draft
   │
   ▼
Published
   │
   ▼
Accepted
   │
   ▼
Escrow Locked
   │
   ▼
Execution
   │
   ▼
Settlement Pending
   │
   ▼
Completed
```

Failure Path

```text
Execution

↓

Failed

↓

Dispute

↓

Resolved
```

---

# Marketplace Lifecycle

```text
Created

↓

Published

↓

Discovered

↓

Negotiated

↓

Agreement Created
```

---

# Escrow Lifecycle

```text
Created

↓

Funded

↓

Locked

↓

Released
```

or

```text
Locked

↓

Refunded
```

---

# Settlement Lifecycle

```text
Pending

↓

Verified

↓

Executed

↓

Finalized
```

---

# Proposal Lifecycle

```text
Created

↓

Open

↓

Voting

↓

Closed

↓

Accepted

↓

Executed
```

Rejected Path

```text
Closed

↓

Rejected

↓

Archived
```

---

# Delegation Lifecycle

```text
Created

↓

Active

↓

Modified

↓

Revoked

↓

Expired
```

---

# Memory Lifecycle

```text
Generated

↓

Validated

↓

Recorded

↓

Immutable

↓

Referenced
```

---

# Reputation Lifecycle

```text
Observation

↓

Evidence

↓

Evaluation

↓

Published

↓

Historical Record
```

---

# Global Protocol State

```text
Identity

↓

Capability

↓

Marketplace

↓

Agreement

↓

Escrow

↓

Execution

↓

Settlement

↓

Reputation

↓

Memory
```

Every valid protocol execution SHALL follow this ordering.

No module SHALL bypass a lower protocol layer.
