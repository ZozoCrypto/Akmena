// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../interfaces/IAgentTreasuryEngine.sol";

contract AgentTreasuryEngine is IAgentTreasuryEngine {
    error ZeroAmount();
    error InsufficientBalance();

    Treasury internal treasury;

    function deposit(uint256 amount) external {
        if (amount == 0) {
            revert ZeroAmount();
        }

        treasury.balance += amount;
        treasury.lastUpdated = block.timestamp;

        emit Deposited(amount);
    }

    function withdraw(uint256 amount) external {
        if (amount == 0) {
            revert ZeroAmount();
        }

        if (treasury.balance < amount) {
            revert InsufficientBalance();
        }

        treasury.balance -= amount;
        treasury.lastUpdated = block.timestamp;

        emit Withdrawn(amount);
    }

    function getTreasury() external view returns (Treasury memory) {
        return treasury;
    }

    function balance() external view returns (uint256) {
        return treasury.balance;
    }
}
