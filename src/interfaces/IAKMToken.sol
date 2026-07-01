// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IAKMAuthorization} from "./IAKMAuthorization.sol";

/// @title IAKMToken
/// @notice ERC20 interface for the Akmena Token.
interface IAKMToken is IERC20, IAKMAuthorization {
    /// @notice Returns the immutable maximum token supply.
    function maxSupply() external view returns (uint256);
}
