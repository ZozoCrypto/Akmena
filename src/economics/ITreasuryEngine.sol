// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title ITreasuryEngine
/// @notice Canonical single-asset Treasury boundary for Akmena.
interface ITreasuryEngine {
    event TreasuryFunded(
        address indexed from,
        uint256 amount
    );

    event FundsDisbursed(
        address indexed to,
        uint256 amount
    );

    error InvalidAddress();
    error InvalidAmount();
    error Unauthorized();
    error InsufficientTreasuryFunds();
    error InvalidToken();

    function token() external view returns (address);

    function owner() external view returns (address);

    function fundTreasury(
        uint256 amount
    ) external;

    function disburseFunds(
        address to,
        uint256 amount
    ) external;

    function getTreasuryState()
        external
        view
        returns (
            uint256 totalSupply,
            uint256 treasuryBalance
        );
}
