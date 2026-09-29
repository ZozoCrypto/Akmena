// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AkmenaCore} from "../core/AkmenaCore.sol";
import {LibStorage} from "../storage/LibStorage.sol";
import {AkmenaExecutionAuthorization} from "./AkmenaExecutionAuthorization.sol";
import {ITransientProofVerifier} from "./ITransientProofVerifier.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

contract AkmenaPolicyBoundary is ReentrancyGuardTransient {
    AkmenaCore public immutable core;
    AkmenaExecutionAuthorization public immutable executionAuthorization;

    struct SpendingPolicy {
        uint256 maxSpendPerTransaction;
        uint256 dailyLimit;
        uint256 totalSpentToday;
        uint256 lastResetTimestamp;
        bool requireActiveEscrow;
    }

    // Native-value policies. address(0) is the native asset.
    mapping(address => mapping(address => SpendingPolicy)) public agentPolicies;

    // ERC20 policies are isolated by the exact token contract address.
    mapping(address => mapping(address => mapping(address => SpendingPolicy))) public agentAssetPolicies;

    // Explicit economic execution allowlist.
    // Keyed by asset => adapter target.
    mapping(address => mapping(address => bool)) public economicAdapters;

    error PolicyExceeded();
    error EscrowPrerequisiteFailed();
    error UnauthorizedAgent();
    error ExecutionFailed();
    error InvalidTransientProof();
    error ProtocolPaused();
    error InvalidCore();
    error LegacyExecutionDisabled();
    error InvalidAsset();
    error UnauthorizedAdapterAdmin();
    error InvalidAdapter();
    error EconomicAdapterNotAllowed();
    error NativeValueMismatch();
    error EconomicSpendExceedsIntent();
    error EconomicBalanceIncrease();

    constructor(address _core) {
        if (_core == address(0) || _core.code.length == 0) {
            revert InvalidCore();
        }

        core = AkmenaCore(_core);
        executionAuthorization = new AkmenaExecutionAuthorization();
    }

    /// @notice Configure the native-value policy (asset = address(0)).
    function setAgentPolicy(address agent, uint256 maxSpend, uint256 daily, bool requireEscrow) external {
        agentPolicies[msg.sender][agent] = SpendingPolicy({
            maxSpendPerTransaction: maxSpend,
            dailyLimit: daily,
            totalSpentToday: 0,
            lastResetTimestamp: block.timestamp,
            requireActiveEscrow: requireEscrow
        });
    }

    /// @notice Configure an isolated policy for one ERC20 asset.
    /// @dev Limits are denominated in that asset's smallest units.
    function setAgentAssetPolicy(address agent, address asset_, uint256 maxSpend, uint256 daily, bool requireEscrow)
        external
    {
        if (asset_ == address(0) || asset_.code.length == 0) {
            revert InvalidAsset();
        }

        agentAssetPolicies[msg.sender][agent][asset_] = SpendingPolicy({
            maxSpendPerTransaction: maxSpend,
            dailyLimit: daily,
            totalSpentToday: 0,
            lastResetTimestamp: block.timestamp,
            requireActiveEscrow: requireEscrow
        });
    }

    /// @notice Allow or revoke a trusted economic adapter for one ERC20 asset.
    /// @dev Only the AkmenaCore deployer may change this allowlist.
    function setEconomicAdapter(address asset_, address adapter, bool enabled) external {
        if (msg.sender != core.deployer()) {
            revert UnauthorizedAdapterAdmin();
        }

        if (asset_ == address(0) || asset_.code.length == 0) {
            revert InvalidAsset();
        }

        if (adapter == address(0) || adapter.code.length == 0) {
            revert InvalidAdapter();
        }

        economicAdapters[asset_][adapter] = enabled;
    }

    function _policy(address operator, address agent, address asset_)
        internal
        view
        returns (SpendingPolicy storage policy)
    {
        if (asset_ == address(0)) {
            policy = agentPolicies[operator][agent];
        } else {
            policy = agentAssetPolicies[operator][agent][asset_];
        }
    }

    function _verifyActiveEscrow(
        SpendingPolicy storage policy,
        AkmenaExecutionAuthorization.ExecutionIntent calldata intent,
        address agent
    ) internal view {
        if (!policy.requireActiveEscrow) {
            return;
        }

        (address moduleAddr, bool active,) = core.getModule(intent.proofModuleKey);

        require(active, "Proof Module Offline");

        bool hasProof = ITransientProofVerifier(moduleAddr)
            .verifyTransientProof(intent.proofId, agent, intent.asset, intent.amount);

        if (!hasProof) {
            revert InvalidTransientProof();
        }
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
    ) external payable nonReentrant returns (bytes memory) {
        if (core.isPaused()) {
            revert ProtocolPaused();
        }

        address agent = msg.sender;

        if (agent == address(0)) {
            revert UnauthorizedAgent();
        }

        if (intent.asset != address(0) && intent.asset.code.length == 0) {
            revert InvalidAsset();
        }

        if (intent.agent != agent) {
            revert UnauthorizedAgent();
        }

        if (intent.operator == address(0)) {
            revert UnauthorizedAgent();
        }

        bool isNative = intent.asset == address(0);
        bool isEconomicAdapter = !isNative && economicAdapters[intent.asset][intent.target];

        if (isNative) {
            // The signed native value must equal the actual value supplied.
            if (msg.value != intent.value) {
                revert NativeValueMismatch();
            }

            // For an actual native transfer, amount is the policy-denominated
            // economic amount and must equal the real value transferred.
            if (msg.value > 0 && intent.amount != msg.value) {
                revert NativeValueMismatch();
            }
        } else {
            // ERC20 economic execution is never allowed to carry native ETH.
            if (msg.value != 0) {
                revert NativeValueMismatch();
            }

            // A direct call into the asset contract is itself an economic
            // operation and therefore requires an explicitly trusted adapter.
            if (intent.target == intent.asset && !isEconomicAdapter) {
                revert EconomicAdapterNotAllowed();
            }
        }

        SpendingPolicy storage policy = _policy(intent.operator, agent, intent.asset);

        if (policy.maxSpendPerTransaction == 0) {
            revert UnauthorizedAgent();
        }

        // Reset the rolling 24-hour spending window first.
        // Intentional timestamp boundary: spending policy resets on a rolling 24-hour window.
        // forge-lint: disable-next-line(block-timestamp)
        if (block.timestamp > policy.lastResetTimestamp + 1 days) {
            policy.totalSpentToday = 0;
            policy.lastResetTimestamp = block.timestamp;
        }

        // The intent amount is an upper bound on economic execution.
        // For native transfers this is exact because msg.value is observable.
        // For ERC20 calls this is verified against measured token spend below.
        if (intent.amount > policy.maxSpendPerTransaction) {
            revert PolicyExceeded();
        }

        // Preserve existing zero-value generic execution semantics.
        // These calls are authorization/proof-context operations rather than
        // measured native spending, so their declared amount remains the
        // policy-accounted amount.
        if (isNative && msg.value == 0) {
            if (intent.amount > policy.dailyLimit - policy.totalSpentToday) {
                revert PolicyExceeded();
            }
        }

        _verifyActiveEscrow(policy, intent, agent);

        executionAuthorization.verifyAndConsume(intent, payload, msg.value, signature);

        uint256 balanceBefore;

        if (!isNative) {
            balanceBefore = IERC20(intent.asset).balanceOf(address(this));
        }

        (bool success, bytes memory returnData) = intent.target.call{value: msg.value}(payload);

        if (!success) {
            assembly {
                revert(add(returnData, 32), mload(returnData))
            }
        }

        if (isNative) {
            if (msg.value > 0) {
                // Actual native spend is exactly the ETH forwarded by this call.
                if (msg.value > policy.dailyLimit - policy.totalSpentToday) {
                    revert PolicyExceeded();
                }

                policy.totalSpentToday += msg.value;
            } else {
                policy.totalSpentToday += intent.amount;
            }
        } else {
            uint256 balanceAfter = IERC20(intent.asset).balanceOf(address(this));

            // A net balance increase during the call (rebasing / reflection
            // tokens, adapter-driven mints) must never be silently absorbed
            // into a zero-spend reading: value left custody unrecorded.
            if (balanceAfter > balanceBefore) {
                revert EconomicBalanceIncrease();
            }

            uint256 spent = balanceBefore - balanceAfter;

            // Generic ERC20-context calls are allowed only when they do not
            // actually spend tokens from PolicyBoundary custody.
            if (spent > 0 && !isEconomicAdapter) {
                revert EconomicAdapterNotAllowed();
            }

            // Economic adapters must honor the signed economic ceiling.
            if (spent > intent.amount) {
                revert EconomicSpendExceedsIntent();
            }

            if (spent > policy.maxSpendPerTransaction) {
                revert PolicyExceeded();
            }

            if (spent > policy.dailyLimit - policy.totalSpentToday) {
                revert PolicyExceeded();
            }

            // Record the measured economic effect, never the declaration.
            policy.totalSpentToday += spent;
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
