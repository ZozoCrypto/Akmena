// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaCore} from "../../../src/core/AkmenaCore.sol";
import {AkmenaPolicyBoundary} from "../../../src/authorization/AkmenaPolicyBoundary.sol";
import {AkmenaExecutionAuthorization} from "../../../src/authorization/AkmenaExecutionAuthorization.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @notice Fuzzable ERC20 with configurable adversarial transfer semantics.
/// @dev Modes:
///   0 = honest (plain ERC20)
///   1 = over-pull (transferFrom takes amount + 10%)
///   2 = silent-success (transfer/transferFrom return true, move nothing)
///   3 = short-delivery (transfer sends amount - 10%)
///   4 = fee-on-transfer (transfer burns 5% fee)
contract FuzzToken is ERC20 {
    uint8 public mode;

    uint256 public constant OVERPULL_BPS = 1000; // 10%
    uint256 public constant SHORTFALL_BPS = 1000; // 10%
    uint256 public constant FEE_BPS = 500; // 5%

    constructor() ERC20("FuzzToken", "FZ") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function setMode(uint8 m) external {
        require(m <= 4, "bad mode");
        mode = m;
    }

    function transferFrom(address from, address to, uint256 amount)
        public
        override
        returns (bool)
    {
        if (mode == 1) {
            // Over-pull: take more than the requested amount.
            uint256 overpull = amount + (amount * OVERPULL_BPS / 10000);
            return super.transferFrom(from, to, overpull);
        } else if (mode == 2) {
            // Silent success: return true, move nothing.
            return true;
        }
        return super.transferFrom(from, to, amount);
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        if (mode == 2) {
            // Silent success: return true, move nothing.
            return true;
        } else if (mode == 3) {
            // Short delivery: send 10% less than requested.
            uint256 short = amount - (amount * SHORTFALL_BPS / 10000);
            return super.transfer(to, short);
        } else if (mode == 4) {
            // Fee on transfer: burn 5%, deliver 95%.
            uint256 fee = (amount * FEE_BPS / 10000);
            _burn(msg.sender, fee);
            return super.transfer(to, amount - fee);
        }
        return super.transfer(to, amount);
    }
}

/// @notice Recording adapter for R9 fuzzing.
contract FuzzAdapter {
    uint256 public totalReceived;
    mapping(address => uint256) public receivedFrom;

    function execute(uint256 amount) external returns (bool) {
        totalReceived += amount;
        receivedFrom[msg.sender] += amount;
        return true;
    }
}

/// @notice Adapter that attempts reentry during the post-push callback.
/// @dev Stores an intent/signature; on execute() it tries a reentrant
/// executeAuthorizedAgentCall. The reentry must never succeed.
contract ReentrantFuzzAdapter {
    AkmenaPolicyBoundary public boundary;
    uint256 public totalReceived;
    uint256 public reentryAttempts;
    uint256 public reentrySuccesses;

    AkmenaExecutionAuthorization.ExecutionIntent internal _storedIntent;
    bytes internal _storedPayload;
    bytes internal _storedSig;
    bool public hasStored;

    constructor(address _boundary) {
        boundary = AkmenaPolicyBoundary(_boundary);
    }

    function storeForReentry(
        AkmenaExecutionAuthorization.ExecutionIntent calldata intent,
        bytes calldata payload,
        bytes calldata sig
    ) external {
        _storedIntent = intent;
        _storedPayload = payload;
        _storedSig = sig;
        hasStored = true;
    }

    function execute(uint256 amount) external returns (bool) {
        totalReceived += amount;
        if (hasStored) {
            reentryAttempts++;
            try boundary.executeAuthorizedAgentCall(_storedIntent, _storedPayload, _storedSig) {
                reentrySuccesses++;
            } catch {
                // Expected: reverts (nonReentrant, UnauthorizedAgent, or
                // NonceAlreadyUsed). The invariant is reentrySuccesses == 0.
            }
        }
        return true;
    }
}

/// @notice R9 handler for Model D boundary invariants.
/// @dev Extends the R8 handler with:
/// - Non-vacuous nonce tracking (per-agent, iterable, verifiable against
///   the contract's usedNonces mapping).
/// - Revert atomicity snapshots (nonce, charge, balances unchanged on revert).
/// - Malicious-token modes (over-pull, silent, short, fee).
/// - Governance-transition actions (adapter/token add/remove, policy reconfig).
/// - Time warps with lazy reset detection (ghost syncs when contract resets).
/// - Reentrant adapter (reentry attempts must never succeed).
/// - Two operator/agent pairs for cross-operator isolation.
///
/// Ghost accounting:
/// - totalPulledFromOperator / totalPushedToAdapter: cumulative token
///   movements, never reset (measured balance deltas, always accurate).
/// - charged1 / charged2: per-pair daily charge ghosts. Reset when the
///   contract resets totalSpentToday (lazy detection in settle(), or
///   immediate on govReconfigurePolicy).
contract ModelDBoundaryHandlerV2 is Test {
    AkmenaCore public core;
    AkmenaPolicyBoundary public boundary;
    AkmenaExecutionAuthorization public auth;
    FuzzToken public token;
    FuzzAdapter public adapter;
    ReentrantFuzzAdapter public reentrantAdapter;

    uint256 internal constant OPERATOR1_KEY = 0x0E7A71;
    uint256 internal constant OPERATOR2_KEY = 0x0E7A72;
    uint256 internal constant AGENT1_KEY = 0xA6E171;
    uint256 internal constant AGENT2_KEY = 0xA6E172;

    address public operator1;
    address public operator2;
    address public agent1;
    address public agent2;

    // Ghost state.
    uint256 public successfulSettlements;
    uint256 public totalPulledFromOperator; // cumulative, never reset
    uint256 public totalPushedToAdapter; // cumulative, never reset
    uint256 public charged1; // operator1's daily charge ghost
    uint256 public charged2; // operator2's daily charge ghost
    uint256 public dayPushed1; // operator1's daily pushed ghost
    uint256 public dayPushed2; // operator2's daily pushed ghost

    // Honest-mode tracking: if any settlement occurred in non-honest mode,
    // the exact-conservation invariants are skipped (cumulative history is polluted).
    bool public everNonHonest;

    // Nonce tracking: per-agent, iterable for invariant verification.
    uint256 public nonceCounter;
    mapping(address => mapping(uint256 => bool)) public nonceUsed;
    mapping(address => uint256[]) public usedNonceList;

    // Revert atomicity.
    uint256 public revertCount;
    uint256 public revertAtomicityViolations;

    uint8 public constant MODE_HONEST = 0;

    // Storage snapshot for revert atomicity (avoids stack-too-deep).
    uint256 private _snapOpBal;
    uint256 private _snapBoundaryBal;
    uint256 private _snapAdapterBal;
    uint256 private _snapSpent;
    bool private _snapNonce;

    constructor() {
        operator1 = vm.addr(OPERATOR1_KEY);
        operator2 = vm.addr(OPERATOR2_KEY);
        agent1 = vm.addr(AGENT1_KEY);
        agent2 = vm.addr(AGENT2_KEY);

        core = new AkmenaCore();
        boundary = new AkmenaPolicyBoundary(address(core));
        auth = boundary.executionAuthorization();
        token = new FuzzToken();
        adapter = new FuzzAdapter();
        reentrantAdapter = new ReentrantFuzzAdapter(address(boundary));

        // Fund both operators, approve boundary, set policies.
        token.mint(operator1, 1_000_000 ether);
        token.mint(operator2, 1_000_000 ether);

        vm.startPrank(operator1);
        token.approve(address(boundary), type(uint256).max);
        boundary.setAgentAssetPolicy(agent1, address(token), 100 ether, 1000 ether, false);
        vm.stopPrank();

        vm.startPrank(operator2);
        token.approve(address(boundary), type(uint256).max);
        boundary.setAgentAssetPolicy(agent2, address(token), 100 ether, 1000 ether, false);
        vm.stopPrank();

        // Admit token and adapters (deployer is allowlistAdmin).
        boundary.setStandardDebit(address(token), true);
        boundary.setEconomicAdapter(address(token), address(adapter), true);
        boundary.setEconomicAdapter(address(token), address(reentrantAdapter), true);
    }

    /// @dev Pick operator/agent pair by seed. Returns (operator, agent, agentKey, isPair1).
    function _actors(uint256 seed)
        internal
        view
        returns (address operator, address agent, uint256 agentKey, bool isPair1)
    {
        if (seed % 2 == 0) {
            return (operator1, agent1, AGENT1_KEY, true);
        } else {
            return (operator2, agent2, AGENT2_KEY, false);
        }
    }

    /// @dev Check if the contract will reset totalSpentToday on the next
    /// executeAuthorizedAgentCall for this pair.
    /// @dev Must be called BEFORE the settlement; the result is only valid
    /// if the settlement succeeds (a revert rolls back the contract's reset).
    function _willReset(address operator, address agent) internal view returns (bool) {
        (,,, uint256 lastReset,) = boundary.agentAssetPolicies(operator, agent, address(token));
        return block.timestamp > lastReset + 1 days;
    }

    /// @dev Build and sign a settlement intent. Returns (intent, payload, sig).
    /// @dev Extracted to avoid stack-too-deep in settle().
    function _buildSignedIntent(
        address operator,
        address agent,
        uint256 agentKey,
        address target,
        bytes4 selector,
        uint256 amount,
        uint256 nonce
    )
        internal
        view
        returns (
            AkmenaExecutionAuthorization.ExecutionIntent memory intent,
            bytes memory payload,
            bytes memory sig
        )
    {
        payload = abi.encodeWithSelector(selector, amount);
        intent = AkmenaExecutionAuthorization.ExecutionIntent({
            operator: operator,
            agent: agent,
            target: target,
            selector: selector,
            calldataHash: keccak256(payload),
            asset: address(token),
            amount: amount,
            value: 0,
            proofModuleKey: bytes32(0),
            proofId: 0,
            nonce: nonce,
            validAfter: 0,
            deadline: block.timestamp + 1 days
        });

        bytes32 digest = auth.hashIntent(intent);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(agentKey, digest);
        sig = abi.encodePacked(r, s, v);
    }

    /// @dev Attempt a randomized settlement. Records ghost state on success;
    /// verifies atomicity on revert.
    function settle(uint256 amountSeed, uint256 nonceSeed, uint256 actorSeed) external {
        (address operator, address agent, uint256 agentKey, bool isPair1) = _actors(actorSeed);

        uint256 amount = bound(amountSeed, 0, 200 ether);
        nonceCounter++;
        uint256 nonce = nonceCounter + bound(nonceSeed, 0, 1000);

        // Skip if this agent already used this nonce (would revert).
        if (nonceUsed[agent][nonce]) return;

        // Track if this settlement is in non-honest mode.
        bool isHonestNow = (token.mode() == MODE_HONEST);
        if (!isHonestNow) everNonHonest = true;

        (
            AkmenaExecutionAuthorization.ExecutionIntent memory intent,
            bytes memory payload,
            bytes memory sig
        ) = _buildSignedIntent(
            operator, agent, agentKey, address(adapter),
            FuzzAdapter.execute.selector, amount, nonce
        );

        // Snapshot for revert atomicity check (in storage to avoid stack-too-deep).
        _snapOpBal = token.balanceOf(operator);
        _snapBoundaryBal = token.balanceOf(address(boundary));
        _snapAdapterBal = token.balanceOf(address(adapter));
        (,, _snapSpent,,) = boundary.agentAssetPolicies(operator, agent, address(token));
        _snapNonce = auth.usedNonces(agent, nonce);
        // Check if contract will reset (valid only if call succeeds).
        bool willReset = _willReset(operator, agent);

        vm.prank(agent);
        try boundary.executeAuthorizedAgentCall(intent, payload, sig) {
            // Success: record ghost state.
            successfulSettlements++;
            nonceUsed[agent][nonce] = true;
            usedNonceList[agent].push(nonce);

            uint256 pulled = _snapOpBal - token.balanceOf(operator);
            uint256 pushed = token.balanceOf(address(adapter)) - _snapAdapterBal;

            totalPulledFromOperator += pulled;
            totalPushedToAdapter += pushed;

            (,, uint256 spentAfter,,) = boundary.agentAssetPolicies(operator, agent, address(token));
            if (willReset) {
                // Contract reset totalSpentToday to 0 then added this settlement.
                // Ghost is just this settlement's values.
                if (isPair1) {
                    charged1 = spentAfter;
                    dayPushed1 = pushed;
                } else {
                    charged2 = spentAfter;
                    dayPushed2 = pushed;
                }
            } else {
                uint256 charge = spentAfter - _snapSpent;
                if (isPair1) {
                    charged1 += charge;
                    dayPushed1 += pushed;
                } else {
                    charged2 += charge;
                    dayPushed2 += pushed;
                }
            }
        } catch {
            revertCount++;
            // Verify atomicity: nothing changed.
            // Note: if the call reverted, any day-rollover reset was also rolled back,
            // so _snapSpent is still accurate.
            (,, uint256 spentAfter,,) = boundary.agentAssetPolicies(operator, agent, address(token));
            bool atomic =
                auth.usedNonces(agent, nonce) == _snapNonce &&
                token.balanceOf(operator) == _snapOpBal &&
                token.balanceOf(address(boundary)) == _snapBoundaryBal &&
                token.balanceOf(address(adapter)) == _snapAdapterBal &&
                spentAfter == _snapSpent;
            if (!atomic) {
                revertAtomicityViolations++;
            }
        }
    }

    /// @dev Settlement via the reentrant adapter.
    function settleReentrant(uint256 amountSeed, uint256 nonceSeed) external {
        address operator = operator1;
        address agent = agent1;

        uint256 amount = bound(amountSeed, 0, 200 ether);
        nonceCounter++;
        uint256 nonce = nonceCounter + bound(nonceSeed, 0, 1000);

        if (nonceUsed[agent][nonce]) return;

        bool isHonestNow = (token.mode() == MODE_HONEST);
        if (!isHonestNow) everNonHonest = true;

        (
            AkmenaExecutionAuthorization.ExecutionIntent memory intent,
            bytes memory payload,
            bytes memory sig
        ) = _buildSignedIntent(
            operator, agent, AGENT1_KEY, address(reentrantAdapter),
            ReentrantFuzzAdapter.execute.selector, amount, nonce
        );

        reentrantAdapter.storeForReentry(intent, payload, sig);

        _snapOpBal = token.balanceOf(operator);
        _snapAdapterBal = token.balanceOf(address(reentrantAdapter));
        (,, _snapSpent,,) = boundary.agentAssetPolicies(operator, agent, address(token));
        bool willReset = _willReset(operator, agent);

        vm.prank(agent);
        try boundary.executeAuthorizedAgentCall(intent, payload, sig) {
            successfulSettlements++;
            nonceUsed[agent][nonce] = true;
            usedNonceList[agent].push(nonce);

            uint256 pulled = _snapOpBal - token.balanceOf(operator);
            uint256 pushed = token.balanceOf(address(reentrantAdapter)) - _snapAdapterBal;

            totalPulledFromOperator += pulled;
            totalPushedToAdapter += pushed;

            (,, uint256 spentAfter,,) = boundary.agentAssetPolicies(operator, agent, address(token));
            if (willReset) {
                charged1 = spentAfter;
                dayPushed1 = pushed;
            } else {
                charged1 += (spentAfter - _snapSpent);
                dayPushed1 += pushed;
            }
        } catch {
            revertCount++;
        }
    }

    // --- Governance-transition fuzz actions ---

    function govRemoveAdapter() external {
        try boundary.emergencyRemoveEconomicAdapter(address(token), address(adapter)) {} catch {}
    }

    function govAddAdapter() external {
        try boundary.setEconomicAdapter(address(token), address(adapter), true) {} catch {}
    }

    function govRemoveToken() external {
        try boundary.emergencyRemoveStandardDebit(address(token)) {} catch {}
    }

    function govAddToken() external {
        try boundary.setStandardDebit(address(token), true) {} catch {}
    }

    /// @dev Reconfigure policy for one pair. Contract resets totalSpentToday;
    /// reset the matching ghosts to stay in sync.
    function govReconfigurePolicy(uint256 actorSeed, uint256 maxSpendSeed, uint256 dailySeed) external {
        (address operator, address agent,, bool isPair1) = _actors(actorSeed);
        uint256 maxSpend = bound(maxSpendSeed, 0, 200 ether);
        uint256 daily = bound(dailySeed, 0, 2000 ether);

        vm.prank(operator);
        boundary.setAgentAssetPolicy(agent, address(token), maxSpend, daily, false);

        if (isPair1) {
            charged1 = 0;
            dayPushed1 = 0;
        } else {
            charged2 = 0;
            dayPushed2 = 0;
        }
    }

    /// @dev Change the token's adversarial mode. Does not affect contract
    /// accounting, so no ghost reset needed.
    function setTokenMode(uint8 modeSeed) external {
        uint8 m = uint8(bound(modeSeed, 0, 4));
        token.setMode(m);
    }

    /// @dev Warp time forward. The contract resets lazily on next settlement;
    /// the settle() function detects this via _willReset().
    function warpTime(uint256 deltaSeed) external {
        uint256 delta = bound(deltaSeed, 0, 3 days);
        if (delta == 0) return;
        vm.warp(block.timestamp + delta);
    }

    /// @dev Return the list of used nonces for an agent (for invariant verification).
    /// @dev The public mapping getter for nested mappings doesn't return arrays,
    /// so this helper is needed.
    function getUsedNonces(address agent) external view returns (uint256[] memory) {
        return usedNonceList[agent];
    }
}
