// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IIdentity} from "./IIdentity.sol";

/// @title IOrganizationIdentity
/// @notice Interface for multi-signature or decentralized organization identities.
interface IOrganizationIdentity is IIdentity {
    function getThreshold() external view returns (uint256);
    function getSigners() external view returns (address[] memory);
}
