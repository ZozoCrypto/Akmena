// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface ITreasuryEngine {
    event TreasuryFunded(uint256 amount);
    event FundsDisbursed(address indexed to, uint256 amount);
    event SupplyUpdated(uint256 totalSupply, uint256 circulatingSupply);

    error InvalidAddress();
    error InvalidAmount();
    error InsufficientTreasuryFunds();

    function fundTreasury(uint256 amount) external;
    function disburseFunds(address to, uint256 amount) external;
    function updateSupply(uint256 total, uint256 circulating) external;
    function getTreasuryState() external view returns (uint256 total, uint256 circulating, uint256 balance);
}
