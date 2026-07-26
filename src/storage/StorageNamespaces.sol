// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title StorageNamespaces
/// @notice Canonical storage namespace identifiers for the Akmena Protocol.
/// @dev Every storage root SHALL derive from one of these namespaces.
///      No module SHALL invent arbitrary storage slots.
library StorageNamespaces {

// -------------------------------------------------------------------------
// Core Protocol
// -------------------------------------------------------------------------

bytes32 internal constant PROTOCOL =
    keccak256("akmena.storage.protocol");

bytes32 internal constant REGISTRY =
    keccak256("akmena.storage.registry");

bytes32 internal constant CONFIG =
    keccak256("akmena.storage.config");

// -------------------------------------------------------------------------
// Identity Domain
// -------------------------------------------------------------------------

bytes32 internal constant IDENTITY =
    keccak256("akmena.storage.identity");

bytes32 internal constant HUMAN =
    keccak256("akmena.storage.identity.human");

bytes32 internal constant MACHINE =
    keccak256("akmena.storage.identity.machine");

bytes32 internal constant ORGANIZATION =
    keccak256("akmena.storage.identity.organization");

// -------------------------------------------------------------------------
// Authorization Domain
// -------------------------------------------------------------------------

bytes32 internal constant AUTHORIZATION =
    keccak256("akmena.storage.authorization");

bytes32 internal constant CAPABILITY =
    keccak256("akmena.storage.capability");

bytes32 internal constant DELEGATION =
    keccak256("akmena.storage.delegation");

// -------------------------------------------------------------------------
// Economic Domain
// -------------------------------------------------------------------------

bytes32 internal constant TREASURY =
    keccak256("akmena.storage.treasury");

bytes32 internal constant ESCROW =
    keccak256("akmena.storage.escrow");

bytes32 internal constant SETTLEMENT =
    keccak256("akmena.storage.settlement");

bytes32 internal constant ASSET =
    keccak256("akmena.storage.asset");

// -------------------------------------------------------------------------
// Trust Domain
// -------------------------------------------------------------------------

bytes32 internal constant REPUTATION =
    keccak256("akmena.storage.reputation");

bytes32 internal constant VERIFICATION =
    keccak256("akmena.storage.verification");

bytes32 internal constant ATTESTATION =
    keccak256("akmena.storage.attestation");

// -------------------------------------------------------------------------
// Coordination Domain
// -------------------------------------------------------------------------

bytes32 internal constant ORGANIZATIONS =
    keccak256("akmena.storage.organizations");

bytes32 internal constant PROPOSALS =
    keccak256("akmena.storage.proposals");

bytes32 internal constant VOTING =
    keccak256("akmena.storage.voting");

// -------------------------------------------------------------------------
// Autonomous Economy
// -------------------------------------------------------------------------

bytes32 internal constant MARKETPLACE =
    keccak256("akmena.storage.marketplace");

bytes32 internal constant AGREEMENTS =
    keccak256("akmena.storage.agreements");

bytes32 internal constant DISCOVERY =
    keccak256("akmena.storage.discovery");

bytes32 internal constant SERVICES =
    keccak256("akmena.storage.services");

bytes32 internal constant SKILLS =
    keccak256("akmena.storage.skills");

bytes32 internal constant MEMORY =
    keccak256("akmena.storage.memory");

}
