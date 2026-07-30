// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

library StorageNamespaces {
    bytes32 public constant IDENTITY = keccak256("akmena.storage.identity");
    bytes32 public constant REGISTRY = keccak256("akmena.storage.registry");
    bytes32 public constant AUTHORIZATION = keccak256("akmena.storage.authorization");
    bytes32 public constant TREASURY = keccak256("akmena.storage.treasury");
    bytes32 public constant ESCROW = keccak256("akmena.storage.escrow");
    bytes32 public constant SETTLEMENT = keccak256("akmena.storage.settlement");
    bytes32 public constant PAYMENTS = keccak256("akmena.storage.payments");
    bytes32 public constant MARKETPLACE = keccak256("akmena.storage.marketplace");
    bytes32 public constant REPUTATION = keccak256("akmena.storage.reputation");
    bytes32 public constant MEMORY = keccak256("akmena.storage.memory");
    bytes32 public constant DISCOVERY = keccak256("akmena.storage.discovery");
    bytes32 public constant AGREEMENT = keccak256("akmena.storage.agreement");
}
