// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AkmenaCore} from "../core/AkmenaCore.sol";
import {LibStorage} from "../storage/LibStorage.sol";
import {AkmenaExecutionAuthorization} from "./AkmenaExecutionAuthorization.sol";
import {ITransientProofVerifier} from "./ITransientProofVerifier.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

contract AkmenaPolicyBoundary is ReentrancyGuardTransient {
    using SafeERC20 for IERC20;

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
    error InsufficientOperatorAllowance();
    // Legacy measurement-model errors: retained for ABI and test
    // compatibility. Model D settlement never produces them; removal is
    // scheduled alongside the obsolete attack-test updates (Phase 3).
    error EconomicSpendExceedsIntent();
    error EconomicBalanceIncrease();

    /// @notice Emitted when an ERC20 intent settles under Model D custody.
    /// @dev amount is always exactly the signed intent.amount: pull, push,
    /// and call are one atomic unit. Monitored by operators to reconcile
    /// allowance usage against policy charges.
    event ERC20Settled(
        address indexed operator, address indexed agent, address indexed asset, uint256 amount, address target
    );

    /// @notice Emitted when the economic-adapter allowlist changes.
    /// @dev The monitoring trigger for the allowance-rotation path: when an
    /// adapter is removed or disabled, operators must revoke any standing
    /// ERC20 approvals they granted toward executions targeting it. Removal
    /// from this allowlist does NOT revoke operator approvals — only the
    /// operator's own wallet can do that.
    event EconomicAdapterUpdated(address indexed asset, address indexed adapter, bool enabled);

    /// @notice Emitted when a native-value spending policy is (re)configured.
    event AgentPolicyConfigured(
        address indexed operator,
        address indexed agent,
        uint256 maxSpendPerTransaction,
        uint256 dailyLimit,
        bool requireActiveEscrow
    );

    /// @notice Emitted when an ERC20 spending policy is (re)configured.
    event AgentAssetPolicyConfigured(
        address indexed operator,
        address indexed agent,
        address indexed asset,
        uint256 maxSpendPerTransaction,
        uint256 dailyLimit,
        bool requireActiveEscrow
    );

    constructor(address _core) {
        if (_core == address(0) || _core.code.length == 0) {
            revert InvalidCore();
        }

        core = AkmenaCore(_core);
        executionAuthorization = new AkmenaExecutionAuthorization();
    }

    /// @notice Configure the native-value policy (asset = address(0)).
    /// @dev The policy is namespaced under msg.sender as operator: only the
    /// operator's own funds can ever be spent through it. Reconfiguring
    /// resets the daily counters (totalSpentToday = 0, lastResetTimestamp =
    /// now); previously recorded spend is discarded, not preserved.
    function setAgentPolicy(address agent, uint256 maxSpend, uint256 daily, bool requireEscrow) external {
        agentPolicies[msg.sender][agent] = SpendingPolicy({
            maxSpendPerTransaction: maxSpend,
            dailyLimit: daily,
            totalSpentToday: 0,
            lastResetTimestamp: block.timestamp,
            requireActiveEscrow: requireEscrow
        });

        emit AgentPolicyConfigured(msg.sender, agent, maxSpend, daily, requireEscrow);
    }

    /// @notice Configure an isolated policy for one ERC20 asset.
    /// @dev Limits are denominated in that asset's smallest units. The policy
    /// is namespaced under msg.sender as operator, and every ERC20 execution
    /// pulls funds from that same operator's wallet — never from pooled
    /// boundary custody. Reconfiguring resets the daily counters
    /// (totalSpentToday = 0, lastResetTimestamp = now).
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

        emit AgentAssetPolicyConfigured(msg.sender, agent, asset_, maxSpend, daily, requireEscrow);
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

        // A token must never be ENABLED as its own economic adapter: the adapter
        // entrypoint would execute with the token's full ledger control,
        // letting it offset outflows with mints that net-delta spending
        // accounting cannot observe. Revocation (enabled == false) stays
        // permitted so a previously granted self-adapter can always be removed.
        if (adapter == address(0) || adapter.code.length == 0 || (enabled && adapter == asset_)) {
            revert InvalidAdapter();
        }

        economicAdapters[asset_][adapter] = enabled;

        emit EconomicAdapterUpdated(asset_, adapter, enabled);
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
     * Settlement model (Model D — operator-retained custody):
     * - Native: msg.value semantics are exact and unchanged.
     * - ERC20: the boundary holds no pooled tokens. Execution pulls exactly
     *   intent.amount from intent.operator's wallet (which must have approved
     *   the boundary), pushes it to the allowlisted adapter, then calls the
     *   adapter — atomically. The policy charge equals the signed amount and
     *   is recorded before any fund movement; it is never restored.
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

            // Economic value movement is only permitted to allowlisted
            // adapters: settlement pushes operator funds to the target
            // before calling it, so the target must be explicitly trusted.
            if (intent.amount > 0 && !isEconomicAdapter) {
                revert EconomicAdapterNotAllowed();
            }

            // Defense in depth (V-9): a legacy self-adapter grant
            // (economicAdapters[asset][asset], writable only before 00428402)
            // must never be executable for value movement. Target == asset is
            // incoherent in the push model — the push would fund the token
            // contract while the call draws from the boundary's commingled
            // balance — and enables costless griefing of stranded legacy
            // pools (capital-recycled 1:1 destruction of pool funds into the
            // token contract, no profit to the attacker). New grants are
            // already rejected by setEconomicAdapter; this closes the
            // execution path for legacy ones.
            if (intent.amount > 0 && intent.target == intent.asset) {
                revert InvalidAdapter();
            }
        }

        SpendingPolicy storage policy = _policy(intent.operator, agent, intent.asset);

        if (policy.maxSpendPerTransaction == 0) {
            revert UnauthorizedAgent();
        }

        // Reset the rolling 24-hour spending window first.
        // Intentional timestamp boundary: spending policy resets on a rolling 24-hour window.
        // The reset requires STRICTLY more than 1 day to have elapsed: at exactly
        // lastResetTimestamp + 1 days the window has NOT reset; at +1 day + 1 second it has.
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

        if (isNative) {
            (bool success, bytes memory returnData) = intent.target.call{value: msg.value}(payload);

            if (!success) {
                assembly {
                    revert(add(returnData, 32), mload(returnData))
                }
            }

            if (msg.value > 0) {
                // Actual native spend is exactly the ETH forwarded by this call.
                if (msg.value > policy.dailyLimit - policy.totalSpentToday) {
                    revert PolicyExceeded();
                }

                policy.totalSpentToday += msg.value;
            } else {
                policy.totalSpentToday += intent.amount;
            }

            return returnData;
        }

        return _settleERC20(intent, payload, policy);
    }

    /**
     * @notice Model D ERC20 settlement: pull → push → call, atomically.
     * @dev The boundary holds no pooled ERC20. Each economic execution pulls
     * exactly intent.amount from intent.operator, pushes it to the
     * allowlisted adapter, then calls the adapter. The settled amount is
     * exact by construction; nothing is measured.
     *
     * A positive amount implies the target passed the allowlist gate above.
     * A zero amount is a generic call (authorization/proof-context
     * operations): no funds move, nothing is charged.
     */
    function _settleERC20(
        AkmenaExecutionAuthorization.ExecutionIntent calldata intent,
        bytes calldata payload,
        SpendingPolicy storage policy
    ) internal returns (bytes memory) {
        bool success;
        bytes memory returnData;

        if (intent.amount == 0) {
            (success, returnData) = intent.target.call(payload);

            if (!success) {
                assembly {
                    revert(add(returnData, 32), mload(returnData))
                }
            }

            return returnData;
        }

        // Step 8 — operator allowance pre-check: fail closed with a clean
        // error (the transferFrom below would revert anyway).
        if (IERC20(intent.asset).allowance(intent.operator, address(this)) < intent.amount) {
            revert InsufficientOperatorAllowance();
        }

        // Step 9 — daily-limit headroom, saturating. If the operator lowered
        // dailyLimit below totalSpentToday mid-window, headroom is defined as
        // zero: a clean PolicyExceeded, never Panic(0x11).
        uint256 headroom =
            policy.totalSpentToday >= policy.dailyLimit ? 0 : policy.dailyLimit - policy.totalSpentToday;

        if (intent.amount > headroom) {
            revert PolicyExceeded();
        }

        // Step 10 — charge-before-push: the full authorized amount is
        // accounted before any fund movement. Never restored, including on
        // adapter misbehavior.
        policy.totalSpentToday += intent.amount;

        // Step 11 — pull exactly intent.amount from the operator's wallet.
        // `from` is intent.operator, bound by the EIP-712 signature and the
        // operator-namespaced policy: only the operator's own funds can move.
        // forge-lint: disable-next-line(arbitrary-send-erc20)
        IERC20(intent.asset).safeTransferFrom(intent.operator, address(this), intent.amount);

        // Step 12 — push exactly intent.amount to the adapter. Plain
        // transfer: the boundary never grants pull allowances to anyone.
        IERC20(intent.asset).safeTransfer(intent.target, intent.amount);

        // Step 13 — execute the signed payload. The adapter already holds
        // the pushed funds. Any revert rolls back pull, push, charge,
        // and nonce consumption atomically.
        (success, returnData) = intent.target.call(payload);

        if (!success) {
            assembly {
                revert(add(returnData, 32), mload(returnData))
            }
        }

        // Emitted after the external call deliberately: the event attests to
        // completed settlement. Reentrancy is blocked by nonReentrant.
        // forge-lint: disable-next-line(reentrancy-events)
        emit ERC20Settled(intent.operator, intent.agent, intent.asset, intent.amount, intent.target);

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
