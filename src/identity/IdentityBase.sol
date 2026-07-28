// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./IIdentity.sol";

/// @title IdentityBase
/// @notice Shared implementation for all Akmena identities.
/// @dev ERC-1167 clone compatible. Must be initialized exactly once.
abstract contract IdentityBase is Initializable, IIdentity {
    error NotOwner();
    error ZeroOwner();

    uint256 internal _identityId;
    address internal _owner;
    bool internal _active;
    string internal _metadataURI;

    function __IdentityBase_init(uint256 identityId_, address owner_, string memory metadataURI_)
        internal
        onlyInitializing
    {
        if (owner_ == address(0)) revert ZeroOwner();

        _identityId = identityId_;
        _owner = owner_;
        _metadataURI = metadataURI_;
        _active = true;

        emit IdentityActivated(identityId_);
    }

    function initialize(uint256 identityId_, address owner_, string calldata metadataURI_)
        external
        virtual
        initializer
    {
        __IdentityBase_init(identityId_, owner_, metadataURI_);
    }

    function identityId() external view override returns (uint256) {
        return _identityId;
    }

    function owner() external view override returns (address) {
        return _owner;
    }

    function isActive() external view override returns (bool) {
        return _active;
    }

    function metadataURI() external view override returns (string memory) {
        return _metadataURI;
    }

    function protocolVersion() external pure override returns (string memory) {
        return "2.0.0";
    }

    function updateMetadata(string calldata newMetadata) external {
        if (msg.sender != _owner) revert NotOwner();

        _metadataURI = newMetadata;

        emit MetadataUpdated(_identityId, newMetadata);
    }

    function transferOwnership(address newOwner) external {
        if (msg.sender != _owner) revert NotOwner();
        if (newOwner == address(0)) revert ZeroOwner();

        address previous = _owner;
        _owner = newOwner;

        emit OwnershipTransferred(_identityId, previous, newOwner);
    }

    function deactivate() external {
        if (msg.sender != _owner) revert NotOwner();

        _active = false;

        emit IdentityDeactivated(_identityId);
    }

    function identityType() external view virtual override returns (IdentityType) {
        revert("IdentityBase: identity type not implemented");
    }
}
