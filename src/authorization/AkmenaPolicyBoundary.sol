// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AkmenaCore} from "../core/AkmenaCore.sol";
import {LibStorage} from "../storage/LibStorage.sol";
import {AkmenaExecutionAuthorization} from "./AkmenaExecutionAuthorization.sol";
import {ITransientProofVerifier} from "./ITransientProofVerifier.sol";

contract AkmenaPolicyBoundary {
    AkmenaCore public immutable core;
    AkmenaExecutionAuthorization public immutable executionAuthorization;

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
    error ProtocolPaused();
    error InvalidCore();
    error LegacyExecutionDisabled();

    constructor(address _core) {
        if (_core == address(0) || _core.code.length == 0) {
            revert InvalidCore();
        }

        core = AkmenaCore(_core);
        executionAuthorization = new AkmenaExecutionAuthorization();
    }

    function setAgentPolicy(address agent, uint256 maxSpend, uint256 daily, bool requireEscrow) external {
        agentPolicies[msg.sender][agent] = SpendingPolicy({
            maxSpendPerTransaction: maxSpend,
            dailyLimit: daily,
            totalSpentToday: 0,
            lastResetTimestamp: block.timestamp,
            requireActiveEscrow: requireEscrow
        });
    }

    /// @notice Upgraded to accept a dynamic proofModuleKey for zero-knowledge or public verifications

    /**
     * @notice Execute an exact cryptographically authorized intent.
     *
     * The authorization primitive binds:
     * operator, agent, target, selector, calldata,
     * amount, native value, proof context, nonce,
     * and validity window.
     *
     * The boundary retains policy accounting and proof
     * enforcement, while the authorization primitive
     * provides the exact execution-intent binding.
     */
    function executeAuthorizedAgentCall(
        AkmenaExecutionAuthorization.ExecutionIntent calldata intent,
        bytes calldata payload,
        bytes calldata signature
    ) external payable returns (bytes memory) {
        if (core.isPaused()) {
            revert ProtocolPaused();
        }

        address agent = msg.sender;

        if (agent == address(0)) {
            revert UnauthorizedAgent();
        }

        if (intent.agent != agent) {
            revert UnauthorizedAgent();
        }

        if (intent.operator == address(0)) {
            revert UnauthorizedAgent();
        }

        SpendingPolicy storage policy = agentPolicies[intent.operator][agent];

        if (policy.maxSpendPerTransaction == 0) {
            revert UnauthorizedAgent();
        }

        if (intent.amount > policy.maxSpendPerTransaction) {
            revert PolicyExceeded();
        }

        // Reset the rolling 24-hour spending window BEFORE
        // evaluating the new transaction against dailyLimit.
        //
        // Without this ordering, an already-exhausted policy
        // can remain permanently locked after the reset window
        // has elapsed because the PolicyExceeded check executes
        // before the reset.
        if (block.timestamp > policy.lastResetTimestamp + 1 days) {
            policy.totalSpentToday = 0;
            policy.lastResetTimestamp = block.timestamp;
        }

        if (policy.totalSpentToday + intent.amount > policy.dailyLimit) {
            revert PolicyExceeded();
        }

        if (policy.requireActiveEscrow) {
            (address moduleAddr, bool active,) = core.getModule(intent.proofModuleKey);

            require(active, "Proof Module Offline");

            bool hasProof =
                ITransientProofVerifier(moduleAddr).verifyTransientProof(intent.proofId, agent, intent.amount);

            if (!hasProof) {
                revert InvalidTransientProof();
            }
        }

        /*
         * Cryptographic boundary.
         *
         * IMPORTANT:
         * actualValue is taken directly from this call.
         * payload is the actual calldata that will execute.
         *
         * The authorization contract therefore validates
         * the exact execution intent before any stateful
         * policy accounting is committed.
         */
        executionAuthorization.verifyAndConsume(intent, payload, msg.value, signature);

        /*
         * Consume policy budget only after the cryptographic
         * authorization has succeeded.
         */
        policy.totalSpentToday += intent.amount;

        (bool success, bytes memory returnData) = intent.target.call{value: msg.value}(payload);

        if (!success) {
            assembly {
                revert(add(returnData, 32), mload(returnData))
            }
        }

        return returnData;
    }

    /// @notice Deprecated legacy execution entrypoint.
    /// @dev Intentionally disabled. All execution MUST use
    ///      executeAuthorizedAgentCall() so the exact EIP-712
    ///      execution intent is enforced.
    function executeAgentCall(address, address, uint256, bytes32, uint256, bytes calldata)
        external
        pure
        returns (bytes memory)
    {
        revert LegacyExecutionDisabled();
    }
}
