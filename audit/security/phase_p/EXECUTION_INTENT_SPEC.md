# Akmena Execution Intent Specification

## Purpose

ExecutionIntent is the cryptographic authorization object for autonomous
agent execution.

It is NOT an AKM payment authorization.

---

# ExecutionIntent

The canonical execution authorization contains:

    operator
    agent
    target
    selector
    calldataHash
    amount
    value
    proofModuleKey
    proofId
    nonce
    validAfter
    deadline

---

# Canonical Solidity Representation

struct ExecutionIntent {
    address operator;
    address agent;
    address target;
    bytes4 selector;
    bytes32 calldataHash;
    uint256 amount;
    uint256 value;
    bytes32 proofModuleKey;
    uint256 proofId;
    uint256 nonce;
    uint256 validAfter;
    uint256 deadline;
}

---

# Calldata Binding

calldataHash MUST equal:

    keccak256(payload)

The verifier MUST calculate the hash from the actual calldata supplied
to execution.

The caller MUST NOT supply a separate arbitrary calldataHash.

---

# Selector Binding

selector MUST equal:

    bytes4(payload)

The selector MUST therefore be derived from the actual calldata or
validated against the signed selector.

---

# Target Binding

The signed target MUST equal the actual target called by execution.

---

# Value Binding

The signed value MUST equal the native value transferred during execution.

If execution does not support native value, value MUST be zero.

---

# Amount Binding

The signed amount represents the economic amount authorized by the
policy.

Execution MUST NOT permit calldata to cause an economic effect greater
than the authorized amount merely because the declared amount is lower.

---

# Proof Binding

proofModuleKey and proofId form one authorization domain.

A valid proof under one module MUST NOT automatically authorize another
module.

---

# Nonce

Execution authorization uses a dedicated nonce namespace.

Payment authorization nonces MUST NOT be reused for execution authorization.

---

# Deadline

Authorization MUST be rejected when:

    block.timestamp > deadline

If validAfter is used:

    block.timestamp < validAfter

MUST also reject.

---

# Domain Separation

The EIP-712 domain MUST include:

    name
    version
    chainId
    verifyingContract

The verifying contract MUST be the execution authorization verifier.

---

# Replay

Every successful authorization MUST become unusable according to the
chosen nonce/consumption model.

A repeated identical authorization MUST NOT execute twice.

---

# Policy Composition

Cryptographic authorization does not replace policy.

Execution requires:

    valid signature
    +
    valid nonce
    +
    valid time window
    +
    valid policy
    +
    valid proof when required

---

# Security Rule

The protocol MUST verify the exact execution that will occur.

No authorization may mean:

    "agent can generally call target"

It must mean:

    "agent may perform THIS exact authorized execution under THESE
     constraints."
