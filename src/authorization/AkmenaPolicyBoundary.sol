// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AkmenaCore} from "../core/AkmenaCore.sol";
import {IEscrowEngine} from "../economics/IEscrowEngine.sol";
import {LibStorage} from "../storage/LibStorage.sol";

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
        if (msg.sender != agent) revert UnauthorizedAgent();

        SpendingPolicy storage policy = agentPolicies[operator][agent];
        
        if (policy.maxSpendPerTransaction == 0) revert UnauthorizedAgent();
        if (amountToSpend > policy.maxSpendPerTransaction) revert PolicyExceeded();
        
        if (block.timestamp > policy.lastResetTimestamp + 1 days) {
            policy.totalSpentToday = 0;
            policy.lastResetTimestamp = block.timestamp;
        }
        
        if (policy.totalSpentToday + amountToSpend > policy.dailyLimit) revert PolicyExceeded();

        // Cross-Module Deterministic Check
        if (policy.requireActiveEscrow) {
            (address escrowAddr, bool active, ) = core.getModule(bytes32("ESCROW_ENGINE"));
            require(active, "Escrow Engine Offline");
            
            // [PATCH ZERO-DAY]: Strictly enforce the escrow status is FUNDED (1)
            LibStorage.EscrowData memory target = IEscrowEngine(escrowAddr).getEscrow(targetEscrowId); 
            if (target.status != 1) revert EscrowPrerequisiteFailed();
        }

        policy.totalSpentToday += amountToSpend;
        return true;
    }
}
