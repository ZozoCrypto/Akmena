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

    /// @notice Standard-Debit token admission (spec §7.2).
    /// @dev Separate from the adapter allowlist: this answers "does this
    /// asset's transfer semantics make exact-amount settlement possible?"
    /// (asset trust), not "is this contract's code trusted?" (code trust).
    /// Default-deny: every asset starts unadmitted. Positive-amount ERC20
    /// settlement requires explicit admission. INTERIM AUTHORITY: the
    /// AkmenaCore deployer administers this list; moving it behind
    /// timelocked multisig governance is a mainnet prerequisite (G-7).
    mapping(address => bool) public isStandardDebit;

    /// @notice Slow-path allowlist admin (spec §7.1).
    /// @dev Holds the ADD power. In production this is the TimelockController:
    /// adapter/token additions are delayed and cancellable. Initialized to
    /// the core deployer; transferable via setAllowlistAdmin.
    address public allowlistAdmin;

    /// @notice Fast-path emergency admin (spec §7.1).
    /// @dev Holds the REMOVE power only — can never add. In production this
    /// is the multisig directly (no timelock delay): removal must be
    /// executable within 1 hour of decision. Initialized to the core
    /// deployer; transferable via setEmergencyAdmin.
    address public emergencyAdmin;

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
    error InvalidAdmin();
    error InvalidAdapter();
    error EconomicAdapterNotAllowed();
    error NativeValueMismatch();
    error InsufficientOperatorAllowance();
    error UnauthorizedZeroAmountTarget();
    /// @notice Reverted when a positive-amount ERC20 intent names an asset
    /// that has not been admitted to the Standard-Debit allowlist (§7.2).
    /// Default-deny: only explicitly admitted tokens can settle value.
    error StandardDebitNotAdmitted();
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

    /// @notice Emitted when the Standard-Debit token allowlist changes.
    /// @dev The monitoring trigger for token-admission changes. Removal is
    /// fail-closed and immediate: pending signed intents targeting the
    /// removed token revert with StandardDebitNotAdmitted (nonce unconsumed).
    /// Removal does NOT affect operator→boundary allowances on the token
    /// contract — those remain the operator's to rotate.
    event StandardDebitUpdated(address indexed asset, bool enabled);

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

    /// @notice Emitted when the slow-path allowlist admin changes.
    event AllowlistAdminUpdated(address indexed admin);

    /// @notice Emitted when the fast-path emergency admin changes.
    event EmergencyAdminUpdated(address indexed admin);

    constructor(address _core) {
        if (_core == address(0) || _core.code.length == 0) {
            revert InvalidCore();
        }

        core = AkmenaCore(_core);
        executionAuthorization = new AkmenaExecutionAuthorization();

        // Interim: deployer holds both paths. G-7 migrates allowlistAdmin to
        // the TimelockController and emergencyAdmin to the multisig.
        allowlistAdmin = core.deployer();
        emergencyAdmin = core.deployer();
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
    /// @dev Slow path (spec §7.1): only the allowlistAdmin (the timelock in
    /// production) may call this. Additions are therefore delayed and
    /// cancellable; use emergencyRemoveEconomicAdapter for immediate removal.
    function setEconomicAdapter(address asset_, address adapter, bool enabled) external {
        if (msg.sender != allowlistAdmin) {
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

    /// @notice Immediately remove an economic adapter (fast path, spec §7.1).
    /// @dev Only the emergencyAdmin (the multisig directly, no timelock
    /// delay) may call this. Can ONLY remove — there is no emergency add.
    /// Fail-closed: pending signed intents targeting the removed adapter
    /// revert with EconomicAdapterNotAllowed (nonce unconsumed).
    function emergencyRemoveEconomicAdapter(address asset_, address adapter) external {
        if (msg.sender != emergencyAdmin) {
            revert UnauthorizedAdapterAdmin();
        }

        economicAdapters[asset_][adapter] = false;

        emit EconomicAdapterUpdated(asset_, adapter, false);
    }

    /// @notice Admit or remove a token from the Standard-Debit allowlist.
    /// @dev Slow path (spec §7.1): only the allowlistAdmin (the timelock in
    /// production) may call this. Admission requires the off-chain evidence
    /// battery of spec §7.2; this function records the decision, it does not
    /// verify token behavior. For immediate removal use
    /// emergencyRemoveStandardDebit.
    function setStandardDebit(address asset_, bool enabled) external {
        if (msg.sender != allowlistAdmin) {
            revert UnauthorizedAdapterAdmin();
        }

        if (asset_ == address(0) || asset_.code.length == 0) {
            revert InvalidAsset();
        }

        isStandardDebit[asset_] = enabled;

        emit StandardDebitUpdated(asset_, enabled);
    }

    /// @notice Immediately remove a token from the Standard-Debit allowlist
    /// (fast path, spec §7.1).
    /// @dev Only the emergencyAdmin may call this. Can ONLY remove — there
    /// is no emergency admission. Fail-closed: pending signed intents
    /// targeting the removed token revert with StandardDebitNotAdmitted
    /// (nonce unconsumed).
    function emergencyRemoveStandardDebit(address asset_) external {
        if (msg.sender != emergencyAdmin) {
            revert UnauthorizedAdapterAdmin();
        }

        isStandardDebit[asset_] = false;

        emit StandardDebitUpdated(asset_, false);
    }

    /// @notice Transfer the slow-path allowlist admin (G-7 migration).
    /// @dev Only the current allowlistAdmin may transfer. In production this
    /// moves from the deployer to the TimelockController.
    function setAllowlistAdmin(address newAdmin) external {
        if (msg.sender != allowlistAdmin) {
            revert UnauthorizedAdapterAdmin();
        }
        if (newAdmin == address(0)) {
            revert InvalidAdmin();
        }

        allowlistAdmin = newAdmin;

        emit AllowlistAdminUpdated(newAdmin);
    }

    /// @notice Transfer the fast-path emergency admin (G-7 migration).
    /// @dev Only the current emergencyAdmin may transfer. In production this
    /// moves from the deployer to the multisig.
    function setEmergencyAdmin(address newAdmin) external {
        if (msg.sender != emergencyAdmin) {
            revert UnauthorizedAdapterAdmin();
        }
        if (newAdmin == address(0)) {
            revert InvalidAdmin();
        }

        emergencyAdmin = newAdmin;

        emit EmergencyAdminUpdated(newAdmin);
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
        // GAP-2 design note (2026-10-01): native intents intentionally skip the adapter
        // allowlist. Rationale: the agent supplies msg.value from their own wallet; the
        // boundary forwards exactly msg.value and never holds native balance (no receive/
        // fallback). No operator or boundary funds are at risk — economic exposure is the
        // agent's own ETH, bounded per-tx and daily by policy. Residual risk: calls execute
        // with msg.sender == boundary (confused deputy). Integrators MUST NOT grant authority
        // based on msg.sender == boundary alone. See GAP-3 for the ERC20 zero-amount analogue.
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

            // Standard-Debit admission (§7.2): positive-amount settlement
            // requires the asset's transfer semantics to make exact-amount
            // settlement possible. Default-deny — unadmitted tokens cannot
            // move value through the boundary. Zero-amount intents are exempt
            // (no funds move; token semantics are irrelevant).
            if (intent.amount > 0 && !isStandardDebit[intent.asset]) {
                revert StandardDebitNotAdmitted();
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
        // measured native spending. GAP-1 hardening (2026-10-01): zero-value
        // native calls do NOT consume the economic daily limit, as no funds
        // move. Previously, intent.amount was charged, allowing an authorized
        // agent to DoS the operator's daily limit via spam at gas cost only.
        // The economic daily limit bounds funds at risk; zero-value calls
        // have zero economic exposure.
        if (isNative && msg.value == 0) {
            // No headroom check needed: zero-value calls do not consume limit.
            // They are still subject to signature verification, nonce consumption,
            // and the agent must be authorized (policy exists).
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
                // Saturating headroom (F-14): clean PolicyExceeded, never panic.
                uint256 headroom =
                    policy.totalSpentToday >= policy.dailyLimit ? 0 : policy.dailyLimit - policy.totalSpentToday;
                if (msg.value > headroom) {
                    revert PolicyExceeded();
                }

                policy.totalSpentToday += msg.value;
            } else {
                // GAP-1 hardening (2026-10-01): zero-value native calls do not
                // charge the economic daily limit. No funds move, so there is
                // zero economic exposure. Previously this charged intent.amount,
                // allowing DoS via spam.
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
            // GAP-3 hardening (2026-10-01): zero-amount calls may only target
            // registered proof modules or allowlisted adapters. This closes the
            // confused-deputy vector where an authorized agent could invoke
            // arbitrary contracts with the boundary as msg.sender. The stated
            // use case (proof-context/authorization operations) is preserved:
            // proof modules are registered via core.getModule(), and adapters
            // via the economic adapter allowlist.
            (address moduleAddress,,) = core.getModule(intent.proofModuleKey);
            bool isProofModule = moduleAddress != address(0) && moduleAddress == intent.target;
            bool isAdapter = economicAdapters[intent.asset][intent.target];
            if (!isProofModule && !isAdapter) {
                revert UnauthorizedZeroAmountTarget();
            }

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
