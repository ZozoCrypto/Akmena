// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title Akmena Stealth Address Registry
/// @notice Implements ERC-5564 Announcer and ERC-6538 Registry standards.
contract StealthAddressRegistry {
    event Announcement(
        uint256 indexed schemeId,
        address indexed stealthAddress,
        address indexed caller,
        bytes ephemeralPubKey,
        bytes metadata
    );

    event StealthMetaAddressSet(
        address indexed registrant,
        uint256 indexed schemeId,
        bytes stealthMetaAddress
    );

    mapping(address => mapping(uint256 => bytes)) public stealthMetaAddresses;

    function announce(
        uint256 schemeId,
        address stealthAddress,
        bytes calldata ephemeralPubKey,
        bytes calldata metadata
    ) external {
        emit Announcement(schemeId, stealthAddress, msg.sender, ephemeralPubKey, metadata);
    }

    function registerStealthMetaAddress(
        uint256 schemeId,
        bytes calldata stealthMetaAddress
    ) external {
        stealthMetaAddresses[msg.sender][schemeId] = stealthMetaAddress;
        emit StealthMetaAddressSet(msg.sender, schemeId, stealthMetaAddress);
    }

    function getStealthMetaAddress(
        address registrant,
        uint256 schemeId
    ) external view returns (bytes memory) {
        return stealthMetaAddresses[registrant][schemeId];
    }
}
