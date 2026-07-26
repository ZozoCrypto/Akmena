// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./IdentityBase.sol";

/// @title Identity
/// @notice Canonical immutable identity implementation for the Akmena Protocol.
/// @dev Deployed as an ERC-1167 clone through the IdentityFactory.
contract Identity is IdentityBase {

    IdentityType private _type;

    function initialize(
        uint256 identityId_,
        address owner_,
        IdentityType identityType_,
        string calldata metadataURI_
    ) external initializer {
        __IdentityBase_init(
            identityId_,
            owner_,
            metadataURI_
        );

        _type = identityType_;
    }

    function identityType() external view override returns (IdentityType) {
        return _type;
    }
}