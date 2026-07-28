// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./StorageNamespaces.sol";

/// @title LibStorage
/// @notice Canonical storage access library for the Akmena Protocol.
/// @dev All protocol modules SHALL access state exclusively through this library.
library LibStorage {
    // -------------------------------------------------------------------------
    // Identity
    // -------------------------------------------------------------------------

    /// @notice Canonical protocol identity storage.
    /// @dev Single source of truth for protocol identities.
    ///      Identity IDs are immutable.
    ///      Identity ID 0 is permanently reserved.
    struct IdentityStorage {
        /// @notice Next identity ID to allocate.
        /// @dev Starts at 1.
        uint256 nextIdentityId;

        /// @notice Maps immutable identity ID => deployed identity contract.
        mapping(uint256 => address) identityAddress;

        /// @notice Maps deployed identity contract => immutable identity ID.
        mapping(address => uint256) addressToIdentityId;
    }

    // -------------------------------------------------------------------------
    // Registry
    // -------------------------------------------------------------------------

    struct RegistryStorage {
        mapping(bytes32 => address) modules;
        mapping(bytes32 => bool) enabled;
        mapping(bytes32 => string) version;
    }

    // -------------------------------------------------------------------------
    // Authorization
    // -------------------------------------------------------------------------

    struct AuthorizationStorage {
        mapping(address => mapping(bytes32 => bool)) capabilities;
        mapping(address => mapping(address => bool)) delegates;
    }

    // -------------------------------------------------------------------------
    // Treasury
    // -------------------------------------------------------------------------

    struct TreasuryStorage {
        uint256 totalSupply;
        uint256 circulatingSupply;
        uint256 treasuryBalance;
    }

    // -------------------------------------------------------------------------
    // Escrow
    // -------------------------------------------------------------------------

    struct EscrowStorage {
        uint256 nextEscrowId;
    }

    // -------------------------------------------------------------------------
    // Marketplace
    // -------------------------------------------------------------------------

    struct MarketplaceStorage {
        uint256 nextListingId;
    }

    // -------------------------------------------------------------------------
    // Reputation
    // -------------------------------------------------------------------------

    struct ReputationStorage {
        mapping(address => uint256) score;
    }

    // -------------------------------------------------------------------------
    // Memory
    // -------------------------------------------------------------------------

    struct MemoryStorage {
        mapping(bytes32 => bytes32) root;
    }

    // -------------------------------------------------------------------------
    // Storage Accessors
    // -------------------------------------------------------------------------

    function identity() internal pure returns (IdentityStorage storage ds) {
        bytes32 slot = StorageNamespaces.IDENTITY;

        assembly {
            ds.slot := slot
        }
    }

    function registry() internal pure returns (RegistryStorage storage ds) {
        bytes32 slot = StorageNamespaces.REGISTRY;

        assembly {
            ds.slot := slot
        }
    }

    function authorization() internal pure returns (AuthorizationStorage storage ds) {
        bytes32 slot = StorageNamespaces.AUTHORIZATION;

        assembly {
            ds.slot := slot
        }
    }

    function treasury() internal pure returns (TreasuryStorage storage ds) {
        bytes32 slot = StorageNamespaces.TREASURY;

        assembly {
            ds.slot := slot
        }
    }

    function escrow() internal pure returns (EscrowStorage storage ds) {
        bytes32 slot = StorageNamespaces.ESCROW;

        assembly {
            ds.slot := slot
        }
    }

    function marketplace() internal pure returns (MarketplaceStorage storage ds) {
        bytes32 slot = StorageNamespaces.MARKETPLACE;

        assembly {
            ds.slot := slot
        }
    }

    function reputation() internal pure returns (ReputationStorage storage ds) {
        bytes32 slot = StorageNamespaces.REPUTATION;

        assembly {
            ds.slot := slot
        }
    }

    function memoryStorage() internal pure returns (MemoryStorage storage ds) {
        bytes32 slot = StorageNamespaces.MEMORY;

        assembly {
            ds.slot := slot
        }
    }
}
