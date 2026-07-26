// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../identity/IIdentity.sol";

/// @title IRegistry
/// @notice Canonical identity registry for the Akmena Protocol.
/// @dev Allocates immutable protocol identity IDs and indexes deployed identities.
///      Identity IDs are never reused or reassigned.
interface IRegistry {

    // ---------------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------------

    error IdentityAlreadyRegistered();
    error IdentityNotFound();
    error InvalidIdentity();
    error IdentityZeroReserved();

    // ---------------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------------

    event IdentityRegistered(
        uint256 indexed identityId,
        address indexed identity,
        IIdentity.IdentityType identityType
    );

    // ---------------------------------------------------------------------
    // Registration
    // ---------------------------------------------------------------------

    /// @notice Registers a newly deployed identity.
    /// @dev Called by the IdentityFactory.
    function registerIdentity(address identity) external;

    // ---------------------------------------------------------------------
    // Resolution
    // ---------------------------------------------------------------------

    /// @notice Returns the deployed identity contract.
    function identityAddress(
        uint256 identityId
    ) external view returns (address);

    /// @notice Returns the immutable protocol identity ID.
    function identityId(
        address identity
    ) external view returns (uint256);

    /// @notice Returns whether the identity exists.
    function exists(
        uint256 identityId
    ) external view returns (bool);

    /// @notice Returns the next identity ID that will be allocated.
    function nextIdentityId()
        external
        view
        returns (uint256);
}