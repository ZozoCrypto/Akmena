// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

/// @title AkmenaToken
/// @notice Native settlement asset for the Akmena Protocol.
/// @dev Fixed-supply ERC20 with ERC2612 permit support.
contract AkmenaToken is ERC20, ERC20Permit {
    /// @notice Maximum fixed supply.
    uint256 public constant MAX_SUPPLY = 1_000_000_000 ether;

    /// @notice Zero address provided as initial holder.
    error InvalidInitialHolder();

    constructor(address initialHolder) ERC20("Akmena Token", "AKM") ERC20Permit("Akmena Token") {
        if (initialHolder == address(0)) {
            revert InvalidInitialHolder();
        }

        _mint(initialHolder, MAX_SUPPLY);
    }
}
