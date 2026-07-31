// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title Akmena Module Keys
/// @notice Canonical identifiers for protocol modules.
library ModuleKeys {

    bytes32 internal constant WORKFLOW =
        keccak256("akmena.module.workflow");

    bytes32 internal constant SETTLEMENT =
        keccak256("akmena.module.settlement");

    bytes32 internal constant ESCROW =
        keccak256("akmena.module.escrow");

    bytes32 internal constant REPUTATION =
        keccak256("akmena.module.reputation");

    bytes32 internal constant MEMORY =
        keccak256("akmena.module.memory");

    bytes32 internal constant MARKETPLACE =
        keccak256("akmena.module.marketplace");

    bytes32 internal constant IDENTITY =
        keccak256("akmena.module.identity");
}
