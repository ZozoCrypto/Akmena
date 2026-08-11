// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AkmenaCore} from "../core/AkmenaCore.sol";
import {IEscrowEngine} from "../economics/IEscrowEngine.sol";

/// @title AkmenaPolicyBoundary
/// @notice The deterministic gateway between AI Agent execution and protocol liquidity.
/// @dev Prevents AI agents from exceeding human-defined economic policies.
contract AkmenaPolicyBoundary {
    AkmenaCore public immutable core;
    
    struct SpendingPolicy {
        uint256 maxSpendPerTransaction;
        uint256 dailyLimit;
        uint256 totalSpentToday;
        uint256 lastResetTimestamp;
        bool requireActiveEscrow;
    }

    // Mapping: Human Operator -> AI Agent -> SpendingPolicy
    mapping(address => mapping(address => SpendingPolicy)) public agentPolicies;

    error PolicyExceeded();
    error EscrowPrerequisiteFailed();
    error UnauthorizedAgent();

    constructor(address _core) {
        core = AkmenaCore(_core);
    }

    /// @notice Human operator sets the strict mathematical bounds for their AI agent.
    function setAgentPolicy(
        address agent, 
        uint256 maxSpend, 
        uint256 daily, 
        bool requireEscrow
    ) external {
        agentPolicies[msg.sender][agent] = SpendingPolicy({
            maxSpendPerTransaction: maxSpend,
            dailyLimit: daily,
            totalSpentToday: 0,
            lastResetTimestamp: block.timestamp,
            requireActiveEscrow: requireEscrow
        });
    }

    /// @notice The hook called by AgentKit/x402 before executing a Base transaction.
    function validateAgentExecution(
        address operator,
        address agent,
        uint256 amountToSpend,
        uint256 targetEscrowId
    ) external returns (bool) {
        SpendingPolicy storage policy = agentPolicies[operator][agent];
        
        if (policy.maxSpendPerTransaction == 0) revert UnauthorizedAgent();
        if (amountToSpend > policy.maxSpendPerTransaction) revert PolicyExceeded();
        
        // Reset daily limit if 24 hours have passed
        if (block.timestamp > policy.lastResetTimestamp + 1 days) {
            policy.totalSpentToday = 0;
            policy.lastResetTimestamp = block.timestamp;
        }
        
        if (policy.totalSpentToday + amountToSpend > policy.dailyLimit) revert PolicyExceeded();

        // Cross-Module Deterministic Check
        if (policy.requireActiveEscrow) {
            (address escrowAddr, bool active, ) = core.getModule(bytes32("ESCROW_ENGINE"));
            require(active, "Escrow Engine Offline");
            
            // Reverts if the escrow is missing or not authorized
            IEscrowEngine(escrowAddr).getEscrow(targetEscrowId); 
            // Further logic to verify escrow status == 1 (Funded) would go here
        }

        policy.totalSpentToday += amountToSpend;
        return true;
    }
}
