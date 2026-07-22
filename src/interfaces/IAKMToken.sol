// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title IAKMToken
/// @notice Immutable monetary layer interface for the Akmena Protocol.
interface IAKMToken is IERC20 {

    /// @notice Returns the immutable maximum token supply.
    function maxSupply() external view returns (uint256);
}