// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IIdentity} from "./IIdentity.sol";

/// @title IMachineIdentity
/// @notice Interface for autonomous agents and algorithmic execution environments.
interface IMachineIdentity is IIdentity {
    function getController() external view returns (address);
    function executionHash() external view returns (bytes32);
}
