// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IAgentTreasuryEngine {
    struct Treasury {
        uint256 balance;
        uint256 lastUpdated;
    }

    event Deposited(uint256 amount);

    event Withdrawn(uint256 amount);

    function deposit(uint256 amount) external;

    function withdraw(uint256 amount) external;

    function getTreasury() external view returns (Treasury memory);

    function balance() external view returns (uint256);
}
