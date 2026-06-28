// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

/// @title IAKMToken
/// @notice Core interface for the Akmena Token.
interface IAKMToken is IERC20, IERC20Permit {}
