// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IIdentity} from "./IIdentity.sol";

/// @title IHumanIdentity
/// @notice Interface for human actor identities within the protocol.
interface IHumanIdentity is IIdentity {
    function isVerified() external view returns (bool);
}
