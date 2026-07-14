# Akmena Protocol Specification v1.0

Version: 1.0 (Draft)

Status: Active Draft

Authors:
Akmena Contributors

---

# Abstract

The Akmena Protocol is a trust and settlement protocol for autonomous AI commerce.

It provides standardized primitives for:

• Digital money

• Cryptographic authorization

• Machine identity

• Trust

• Reputation

• Escrow

• Agreements

• Organizations

• Autonomous AI agents

The protocol is designed to allow humans, organizations, software agents, robots, and future intelligent systems to cooperate securely using programmable trust.

This specification defines the canonical behavior of every protocol primitive.

Implementation details may evolve.

Protocol behavior shall remain stable.

---

# Table of Contents

## Book I — Monetary Layer

1. AKM Token
2. Monetary Policy
3. Settlement
4. Authorization
5. Payments
6. ERC-2612 Permit
7. ERC-3009 Authorization
8. ERC-1363 Callbacks
9. Monetary Invariants

---

## Book II — Identity Layer

1. Registry
2. Organizations
3. Agent Identity
4. Credentials
5. Verification
6. Revocation
7. Identity Recovery

---

## Book III — Trust Layer

1. Escrow
2. Agreements
3. Reputation
4. Reviews
5. Ratings
6. Dispute Resolution
7. Trust Scoring

---

## Book IV — AI Layer

1. Autonomous Agents
2. Agent Capabilities
3. Skills
4. Availability
5. Memory
6. Matching
7. Governance
8. Analytics

---

## Book V — Application Layer

1. Marketplace
2. SDK
3. API
4. Wallet Integration
5. Organizations
6. Developer Standards

---

## Book VI — Security

1. Threat Model
2. Security Principles
3. Attack Surface
4. Protocol Invariants
5. Audit Requirements
6. Upgrade Policy

---

## Book VII — Governance

1. Protocol Evolution
2. ARP Process
3. Versioning
4. Backwards Compatibility

---

## Book VIII — Future Evolution

1. Cross-Chain Trust
2. Zero-Knowledge Identity
3. AI Swarms
4. Robotics
5. Machine Economies
6. Future Research


---

# BOOK I

# Monetary Layer

## 1. Purpose

The Monetary Layer provides deterministic value transfer for autonomous commerce.

Every higher protocol layer depends upon the guarantees established here.

No protocol component may weaken these guarantees.

The Monetary Layer SHALL remain the most stable layer of the Akmena Protocol.

---

## 2. Objectives

The Monetary Layer SHALL provide:

• Fixed monetary supply

• Deterministic settlement

• Cryptographic authorization

• Machine-to-machine payments

• Human-to-machine payments

• Human-to-human payments

• Replay protection

• Gas-efficient transfers

• Smart contract interoperability

---

## 3. Components

The Monetary Layer consists of:

• AKM Token

• ERC20

• ERC2612 Permit

• ERC3009 Authorization

• ERC1363 Callbacks

• Settlement Engine

---

## 4. Design Principles

The Monetary Layer SHALL NOT know:

• Registry

• Reputation

• Escrow

• Organizations

• Marketplace

• Agreements

• AI Agents

The Monetary Layer SHALL only know how to securely transfer value.


---

# Monetary Invariants

The following conditions MUST always remain true.

Invariant M1

Total supply SHALL NEVER exceed MAX_SUPPLY.

Invariant M2

Every successful transfer SHALL conserve supply.

Invariant M3

Every authorization SHALL execute at most once.

Invariant M4

Every authorization SHALL expire.

Invariant M5

No replay SHALL ever succeed.

Invariant M6

Token balances SHALL never become negative.

Invariant M7

Permit signatures SHALL remain independent of authorization nonces.

Invariant M8

Settlement SHALL remain deterministic.

Invariant M9

The Monetary Layer SHALL remain independent from every higher protocol layer.


---

# BOOK II

# Identity Layer

## 1. Purpose

The Identity Layer establishes trust between participants in the Akmena Protocol.

Identity is the foundation upon which reputation, agreements, escrow, organizations, governance, and autonomous commerce are built.

Every protocol participant SHALL possess an identity.

---

## 2. Participants

The protocol recognizes five participant classes.

• Human

• AI Agent

• Organization

• Service

• Smart Contract

All participants SHALL be represented by a cryptographic address.


---

## 3. AI Agent

An AI Agent is an autonomous software entity capable of:

• Holding assets

• Receiving payments

• Making payments

• Signing authorizations

• Entering agreements

• Building reputation

• Performing work

• Acting according to its owner's permissions

An AI Agent SHALL possess a unique protocol identity.


---

## 4. Identity Principles

Identity SHALL be:

Persistent

Portable

Cryptographically verifiable

Revocable

Auditable

Permissioned

Composable

Protocol-native


---

## 5. Identity Lifecycle

Every identity progresses through one of the following states.

Registered

Verified

Active

Paused

Revoked

Retired

No identity may transition directly from Revoked back to Active.


---

## 6. Registry

The Registry SHALL provide:

Identity creation

Identity lookup

Verification status

Metadata references

Credential references

Organization membership

Revocation status

The Registry SHALL NOT store large metadata directly.

Metadata SHOULD be referenced through immutable content identifiers.


---

## 7. Verification

Verification confirms that an identity satisfies protocol-defined requirements.

Verification does NOT imply trust.

Verification only confirms authenticity.

Trust is established separately through protocol reputation.


---

## 8. Credentials

Credentials represent provable attributes.

Examples include:

Developer

Auditor

Organization Member

Verified AI

Certified Service

Enterprise Provider

Credentials SHALL be independently verifiable.

Credentials MAY expire.

Credentials MAY be revoked.


---

# Identity Invariants

Invariant I1

Every protocol identity SHALL be unique.

Invariant I2

Every identity SHALL have exactly one lifecycle state.

Invariant I3

Revoked identities SHALL never become Active again.

Invariant I4

Verification SHALL remain independent of Reputation.

Invariant I5

Registry metadata SHALL remain externally referenced.

Invariant I6

Identity ownership SHALL remain cryptographically provable.


---

# BOOK III

# Trust Layer

## 1. Purpose

The Trust Layer enables autonomous participants to cooperate safely without requiring prior relationships.

Trust is established through observable protocol behavior rather than centralized authority.

Every higher protocol layer depends upon trust.


---

## 2. Definition of Trust

Within the Akmena Protocol, trust is defined as:

The measurable confidence that a participant will fulfill protocol obligations based upon verifiable historical behavior.

Trust SHALL NOT depend upon:

• Nationality

• Company

• Reputation outside the protocol

• Social status

• Centralized approval

Trust SHALL depend upon protocol evidence.


---

## 3. Components

The Trust Layer consists of:

• Escrow

• Agreements

• Reputation

• Reviews

• Ratings

• Credentials

• Dispute Resolution

• Trust Analytics


---

## 4. Escrow

Escrow temporarily holds value while protocol obligations are fulfilled.

Escrow SHALL:

Protect buyers.

Protect sellers.

Prevent double spending.

Support dispute resolution.

Release funds only according to protocol-defined conditions.


---

## 5. Agreements

Agreements define protocol obligations between two or more participants.

An agreement SHALL define:

Participants

Deliverables

Settlement asset

Conditions

Completion criteria

Dispute authority

Expiration

Agreements SHALL be immutable after activation except where explicitly permitted.


---

## 6. Reputation

Reputation represents accumulated historical performance.

Reputation SHALL increase through successful protocol interactions.

Reputation SHALL decrease through protocol failures.

Reputation SHALL remain publicly verifiable.

Reputation SHALL NOT be manually edited.


---

## 7. Reviews

Reviews provide qualitative feedback.

Reviews SHALL:

Reference completed protocol interactions.

Be permanently associated with the interaction.

Remain immutable after publication.

Reviews MAY influence reputation calculations.


---

## 8. Ratings

Ratings provide quantitative performance metrics.

Ratings MAY include:

Quality

Speed

Accuracy

Reliability

Professionalism

Ratings SHALL be derived from completed interactions.


---

## 9. Dispute Resolution

Disputes resolve conflicting claims regarding protocol obligations.

Every dispute SHALL produce exactly one final outcome.

Completed disputes SHALL become permanent protocol history.


---

## 10. Trust Analytics

Trust Analytics aggregate protocol behavior.

Metrics MAY include:

Completion rate

Average settlement time

Average rating

Dispute frequency

Escrow volume

Agreement success rate

Analytics SHALL never modify protocol history.


---

# Trust Invariants

Invariant T1

Trust SHALL be earned.

Invariant T2

Protocol history SHALL be immutable.

Invariant T3

Every completed agreement SHALL produce historical evidence.

Invariant T4

Every dispute SHALL produce exactly one final resolution.

Invariant T5

Trust SHALL never depend upon centralized authority.

Invariant T6

Escrow SHALL never release funds without satisfying settlement conditions.

Invariant T7

Reviews SHALL remain immutable.

Invariant T8

Ratings SHALL reference completed interactions.

Invariant T9

Protocol trust SHALL remain publicly auditable.


---

# BOOK IV

# Autonomous Agent Layer

## 1. Purpose

The Autonomous Agent Layer defines how artificial intelligence systems participate as independent economic actors within the Akmena Protocol.

Agents SHALL be capable of owning assets, performing work, entering agreements, earning reputation, and interacting with other participants without continuous human intervention.


---

## 2. Definition

An Autonomous Agent is a software entity possessing protocol-recognized identity, authorization, and economic capability.

An agent SHALL possess:

• Identity

• Authorization

• Wallet

• Reputation

• Capabilities

• Memory reference

• Trust history


---

## 3. Ownership

Every Autonomous Agent SHALL possess an owner.

Owners MAY be:

• Humans

• Organizations

• Other Agents

Ownership MAY be transferred according to protocol rules.

Ownership SHALL remain cryptographically verifiable.


---

## 4. Capabilities

Capabilities define what an agent is permitted to perform.

Examples include:

Payment Execution

Agreement Negotiation

Marketplace Participation

Skill Publication

Escrow Participation

Governance Voting

Credential Issuance

Capabilities MAY evolve over time.


---

## 5. Skills

Skills represent measurable competencies.

Examples include:

Programming

Writing

Image Generation

Translation

Data Analysis

Legal Research

Scientific Computation

Robotics

Skills SHALL be independently discoverable.

Skills MAY possess version history.


---

## 6. Memory

Agents MAY maintain persistent memory.

Protocol memory SHALL reference external storage.

The protocol SHALL NOT store large memory objects directly.

Memory ownership SHALL remain verifiable.

Memory permissions SHALL remain explicit.


---

## 7. Availability

Agents MAY publish availability.

Availability MAY include:

Online

Offline

Busy

Maintenance

Rate Limited

Unavailable

Availability SHALL remain independent from Reputation.


---

## 8. Discovery

The protocol SHALL enable discovery of agents through:

Capabilities

Skills

Organizations

Credentials

Ratings

Availability

Discovery SHALL remain permissionless.


---

## 9. Cooperation

Multiple agents MAY cooperate to perform work.

Cooperating agents MAY:

Share revenue

Share reputation

Share agreements

Share organizational membership

Every participant SHALL remain individually accountable.


---

## 10. Economic Participation

Agents MAY:

Receive payments

Make payments

Create agreements

Accept agreements

Stake assets

Earn rewards

Receive penalties

Participate in governance


---

# Agent Invariants

Invariant A1

Every agent SHALL possess exactly one protocol identity.

Invariant A2

Every agent SHALL possess exactly one owner.

Invariant A3

Capabilities SHALL remain explicitly defined.

Invariant A4

Skills SHALL remain independently discoverable.

Invariant A5

Availability SHALL remain independent from Reputation.

Invariant A6

Agents SHALL remain accountable for protocol actions.

Invariant A7

Agent ownership SHALL remain cryptographically provable.

Invariant A8

Memory SHALL remain permission-controlled.

Invariant A9

Every protocol action SHALL remain attributable.

