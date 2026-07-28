// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title IIdentity
/// @notice Canonical identity interface for every participant in the
///         Akmena Protocol.
/// @dev Human, Machine, and Organization identities SHALL implement
///      this interface.
interface IIdentity {
    /// -----------------------------------------------------------------------
    /// Identity Types
    /// -----------------------------------------------------------------------
    enum IdentityType {
        Human,
        Machine,
        Organization
    }

    /// -----------------------------------------------------------------------
    /// Core Identity
    /// -----------------------------------------------------------------------

    /// @notice Returns the immutable protocol identity ID.
    function identityId() external view returns (uint256);

    /// @notice Returns the canonical owner/controller.
    function owner() external view returns (address);

    /// @notice Returns the identity classification.
    function identityType() external view returns (IdentityType);

    /// -----------------------------------------------------------------------
    /// Lifecycle
    /// -----------------------------------------------------------------------

    /// @notice Returns true if the identity is active.
    function isActive() external view returns (bool);

    /// @notice Returns the protocol version implemented.
    function protocolVersion() external pure returns (string memory);

    /// -----------------------------------------------------------------------
    /// Metadata
    /// -----------------------------------------------------------------------

    /// @notice Returns the metadata URI.
    function metadataURI() external view returns (string memory);

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event IdentityActivated(uint256 indexed identityId);

    event IdentityDeactivated(uint256 indexed identityId);

    event MetadataUpdated(uint256 indexed identityId, string metadataURI);

    event OwnershipTransferred(uint256 indexed identityId, address indexed previousOwner, address indexed newOwner);
}
