# Akmena Phase P — Execution Authorization Threat Model

## Objective

Define the security boundary for autonomous-agent execution.

The protocol MUST NOT allow an agent to execute an action unless the
exact execution context is authorized.

---

# 1. Trust Model

## Trusted

- Ethereum consensus
- EVM execution semantics
- Cryptographic primitives
- Correctly implemented EIP-712 domain separation
- Correctly implemented signature recovery
- Protocol-controlled policy state
- Explicitly registered proof modules

## Untrusted

- AI agent
- Agent private key
- Agent-generated calldata
- Agent-selected target
- Agent-selected function selector
- Agent-selected proof module
- Agent-selected proof ID
- Relayers
- Bundlers
- Frontend
- RPC providers
- External contracts
- User-provided payloads

The frontend and AI agent are NEVER authorization authorities.

---

# 2. Security Objective

An execution is valid only when:

    signer
    ==
    authorized operator

AND

    agent
    ==
    authorized agent

AND

    target
    ==
    authorized target

AND

    selector
    ==
    authorized selector

AND

    calldataHash
    ==
    keccak256(actual calldata)

AND

    amount
    ==
    authorized amount

AND

    value
    ==
    authorized native value

AND

    proofModule
    ==
    authorized proof domain

AND

    proofId
    ==
    authorized proof

AND

    nonce
    ==
    expected nonce

AND

    deadline
    >=
    current timestamp

AND

    policy permits execution

---

# 3. Threats

## P-01 Operator substitution

Attacker attempts to use another operator's policy.

Expected result:

    REJECT

## P-02 Agent substitution

Attacker attempts to execute using another agent's authorization.

Expected result:

    REJECT

## P-03 Target substitution

Authorized target A is replaced with target B.

Expected result:

    REJECT

## P-04 Selector substitution

Authorized function A is replaced with privileged function B.

Expected result:

    REJECT

## P-05 Calldata substitution

Authorized calldata is replaced with different calldata.

Expected result:

    REJECT

## P-06 Economic substitution

Declared amount differs from the amount encoded in execution calldata.

Expected result:

    REJECT

## P-07 Native value substitution

Authorized native value differs from execution value.

Expected result:

    REJECT

## P-08 Proof-domain substitution

Authorized proof module is replaced with another proof module.

Expected result:

    REJECT

## P-09 Proof identity substitution

Authorized proof ID is replaced with another proof ID.

Expected result:

    REJECT

## P-10 Replay

A previously consumed authorization is submitted again.

Expected result:

    REJECT

## P-11 Expiry

Authorization is submitted after deadline.

Expected result:

    REJECT

## P-12 Premature execution

Authorization is submitted before validAfter.

Expected result:

    REJECT

## P-13 Policy bypass

Signed authorization exceeds the active policy.

Expected result:

    REJECT

## P-14 Daily-limit bypass

Multiple executions collectively exceed daily policy.

Expected result:

    REJECT

## P-15 Cross-domain replay

Authorization created for one chain or contract is replayed elsewhere.

Expected result:

    REJECT

## P-16 Reentrancy

Target attempts to reenter execution authorization.

Expected result:

    REJECT

## P-17 Module substitution

A proof module is disabled or replaced after authorization.

Expected result:

    REJECT

## P-18 Authorization ambiguity

Two different executions produce the same authorization digest.

Expected result:

    IMPOSSIBLE

---

# 4. Fundamental Security Invariant

The protocol MUST bind authorization to the exact execution.

Conceptually:

    AuthorizationDigest
        =
    DomainSeparator
        +
    Hash(
        operator,
        agent,
        target,
        selector,
        calldataHash,
        amount,
        value,
        proofModule,
        proofId,
        nonce,
        validAfter,
        deadline
    )

Any change to a security-relevant field MUST invalidate the authorization.

---

# 5. AI-Agent Security Principle

AI reasoning is not authorization.

The agent may propose:

    "execute swap"

The authorization system decides:

    "is THIS exact swap authorized?"

The protocol MUST assume that the agent may be:

- compromised
- manipulated
- buggy
- hallucinating
- economically exploited
- operating with malicious calldata

Therefore autonomous execution MUST remain bounded by cryptographic and policy controls.

---

# 6. Monetary-Layer Principle

The AKM token MUST NOT understand:

- AI agents
- marketplaces
- policies
- proof modules
- execution targets
- reputation
- agent reasoning

The monetary layer only moves value safely.

Execution authorization belongs above the monetary layer.

---

# 7. Failure Principle

Security checks MUST fail closed.

Unknown:

- signer
- target
- selector
- proof module
- proof ID
- nonce
- policy

MUST NOT produce authorization.

---

# 8. Replay Principle

EIP-712 provides typed structured signing and domain separation.

It does NOT provide application-level replay protection.

Akmena MUST therefore implement explicit nonce/consumption semantics.

---

# 9. Design Requirement

Do not reuse AKM payment authorization as arbitrary execution authorization.

Payment authorization and execution authorization are separate domains.

---

# 10. Phase P Exit Criteria

Phase P is not complete until:

- all substitution attacks reject
- all replay attacks reject
- all expiry attacks reject
- all proof-domain attacks reject
- exact calldata is cryptographically bound
- exact target is cryptographically bound
- exact selector is cryptographically bound
- exact economic value is cryptographically bound
- policy constraints are enforced
- reentrancy is addressed
- fuzz/invariant tests exist
- full regression passes
