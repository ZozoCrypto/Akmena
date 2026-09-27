// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../identity/IIdentity.sol";

/// @title IRegistry
/// @notice Canonical registry interface for Akmena identities.
/// @dev The Registry is the sole allocator of protocol identity IDs.
interface IRegistry {
    // ---------------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------------

    error IdentityAlreadyRegistered();
    error IdentityNotFound();
    error InvalidIdentity();
    error UnauthorizedBinder();
    error FactoryAlreadyBound();
    error InvalidFactory();

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------

    event IdentityRegistered(uint256 indexed identityId, address indexed identity, IIdentity.IdentityType identityType);

    // ---------------------------------------------------------------------
    // Factory Binding
    // ---------------------------------------------------------------------

    /// @notice Binds the canonical IdentityFactory exactly once.
    /// @dev Only the Registry deployer may perform this bootstrap operation.
    function bindIdentityFactory(address factory) external;

    // ---------------------------------------------------------------------
    // Identity Allocation
    // ---------------------------------------------------------------------

    /// @notice Allocates the next canonical protocol identity ID.
    /// @dev Only the IdentityFactory should call this.
    function allocateIdentityId() external returns (uint256);

    /// @notice Returns the next identity ID that will be allocated.
    function nextIdentityId() external view returns (uint256);

    // ---------------------------------------------------------------------
    // Registry
    // ---------------------------------------------------------------------

    function registerIdentity(address identity) external;

    // ---------------------------------------------------------------------
    // Views
    // ---------------------------------------------------------------------

    function identityAddress(uint256 identityId) external view returns (address);

    function identityId(address identity) external view returns (uint256);

    function exists(uint256 identityId) external view returns (bool);
}
