// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AkmenaCore} from "../core/AkmenaCore.sol";
import {IEscrowEngine} from "../economics/IEscrowEngine.sol";
import {LibStorage} from "../storage/LibStorage.sol";

contract AkmenaPolicyBoundary {
    AkmenaCore public immutable core;
    
    struct SpendingPolicy {
        uint256 maxSpendPerTransaction;
        uint256 dailyLimit;
        uint256 totalSpentToday;
        uint256 lastResetTimestamp;
        bool requireActiveEscrow;
    }

    mapping(address => mapping(address => SpendingPolicy)) public agentPolicies;

    error PolicyExceeded();
    error EscrowPrerequisiteFailed();
    error UnauthorizedAgent();
    error ExecutionFailed();

    constructor(address _core) {
        core = AkmenaCore(_core);
    }

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

    /// @notice ATOMIC EXECUTION: Validates policy and executes payload in one EVM frame.
    function executeAgentCall(
        address operator,
        address targetContract,
        uint256 amountToSpend,
        uint256 targetEscrowId,
        bytes calldata payload
    ) external returns (bytes memory) {
        address agent = msg.sender;
        if (agent == address(0)) revert UnauthorizedAgent();

        SpendingPolicy storage policy = agentPolicies[operator][agent];
        
        if (policy.maxSpendPerTransaction == 0) revert UnauthorizedAgent();
        if (amountToSpend > policy.maxSpendPerTransaction) revert PolicyExceeded();
        
        if (block.timestamp > policy.lastResetTimestamp + 1 days) {
            policy.totalSpentToday = 0;
            policy.lastResetTimestamp = block.timestamp;
        }
        
        if (policy.totalSpentToday + amountToSpend > policy.dailyLimit) revert PolicyExceeded();

        if (policy.requireActiveEscrow) {
            (address escrowAddr, bool active, ) = core.getModule(bytes32("ESCROW_ENGINE"));
            require(active, "Escrow Engine Offline");
            
            LibStorage.EscrowData memory targetData = IEscrowEngine(escrowAddr).getEscrow(targetEscrowId); 
            if (targetData.status != 1) revert EscrowPrerequisiteFailed();
        }

        // Optimistic accounting update
        policy.totalSpentToday += amountToSpend;

        // ATOMIC PROXY: Call the target contract with the payload.
        // If this fails, the EVM reverts the entire transaction, rolling back the totalSpentToday.
        (bool success, bytes memory returnData) = targetContract.call(payload);
        if (!success) {
            // Bubble up the revert reason from the target contract
            assembly {
                revert(add(returnData, 32), mload(returnData))
            }
        }

        return returnData;
    }
}
