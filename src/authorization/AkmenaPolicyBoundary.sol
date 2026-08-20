// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AkmenaCore} from "../core/AkmenaCore.sol";
import {LibStorage} from "../storage/LibStorage.sol";

interface ITransientProofVerifier {
    function verifyTransientProof(uint256 proofId, address operator, uint256 amount) external view returns (bool);
}

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
    error InvalidTransientProof();

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

    /// @notice Upgraded to accept a dynamic proofModuleKey for zero-knowledge or public verifications
    function executeAgentCall(
        address operator,
        address targetContract,
        uint256 amountToSpend,
        bytes32 proofModuleKey,
        uint256 proofId,
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
            (address moduleAddr, bool active, ) = core.getModule(proofModuleKey);
            require(active, "Proof Module Offline");
            
            // FORTIFICATION: Route the verification to the specific module's transient memory
            bool hasProof = ITransientProofVerifier(moduleAddr).verifyTransientProof(proofId, agent, amountToSpend);
            if (!hasProof) revert InvalidTransientProof();
        }

        policy.totalSpentToday += amountToSpend;

        (bool success, bytes memory returnData) = targetContract.call(payload);
        if (!success) {
            assembly {
                revert(add(returnData, 32), mload(returnData))
            }
        }

        return returnData;
    }
}
