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
///   5 = rebase (transfer mints/burns up to 5% unpredictably)
///   6 = blacklist (reverts if sender or recipient is blacklisted)
///   7 = pausable (all transfers revert while paused)
contract FuzzTokenV3 is ERC20 {
    uint8 public mode;

    uint256 public constant OVERPULL_BPS = 1000; // 10%
    uint256 public constant SHORTFALL_BPS = 1000; // 10%
    uint256 public constant FEE_BPS = 500; // 5%
    uint256 public constant REBASE_BPS = 500; // up to 5%

    mapping(address => bool) public blacklisted;
    bool public paused;
    uint256 internal _rebaseCounter;

    constructor() ERC20("FuzzTokenV3", "FZ3") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function setMode(uint8 m) external {
        require(m <= 7, "bad mode");
        mode = m;
    }

    function setBlacklisted(address who, bool flag) external {
        blacklisted[who] = flag;
    }

    function setPaused(bool p) external {
        paused = p;
    }

    function _checkBlacklist(address from, address to) internal view {
        if (mode == 6 && (blacklisted[from] || blacklisted[to])) {
            revert("blacklisted");
        }
    }

    function _checkPaused() internal view {
        if (mode == 7 && paused) {
            revert("token paused");
        }
    }

    function transferFrom(address from, address to, uint256 amount)
        public
        override
        returns (bool)
    {
        _checkPaused();
        _checkBlacklist(from, to);
        if (mode == 1) {
            uint256 overpull = amount + (amount * OVERPULL_BPS / 10000);
            return super.transferFrom(from, to, overpull);
        } else if (mode == 2) {
            return true;
        }
        return super.transferFrom(from, to, amount);
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        _checkPaused();
        _checkBlacklist(msg.sender, to);
        if (mode == 2) {
            return true;
        } else if (mode == 3) {
            uint256 short = amount - (amount * SHORTFALL_BPS / 10000);
            return super.transfer(to, short);
        } else if (mode == 4) {
            uint256 fee = (amount * FEE_BPS / 10000);
            _burn(msg.sender, fee);
            return super.transfer(to, amount - fee);
        } else if (mode == 5) {
            // Rebase: unpredictably mint or burn up to 5% on each transfer.
            _rebaseCounter++;
            uint256 delta = (amount * REBASE_BPS / 10000);
            if (_rebaseCounter % 2 == 0) {
                _mint(msg.sender, delta);
            } else {
                uint256 bal = balanceOf(msg.sender);
                _burn(msg.sender, delta > bal ? bal : delta);
            }
            return super.transfer(to, amount);
        }
        return super.transfer(to, amount);
    }
}

/// @notice Recording adapter for R9 V3 fuzzing.
/// @dev totalDeclaredReceived records the DECLARED payload amount, not
/// measured ERC20 balance delta. Named precisely to avoid implying
/// actual receipt.
contract FuzzAdapterV3 {
    uint256 public totalDeclaredReceived;
    mapping(address => uint256) public declaredFrom;

    function execute(uint256 amount) external returns (bool) {
        totalDeclaredReceived += amount;
        declaredFrom[msg.sender] += amount;
        return true;
    }
}

/// @notice Adapter that attempts reentry during the post-push callback.
contract ReentrantFuzzAdapterV3 {
    AkmenaPolicyBoundary public boundary;
    uint256 public totalDeclaredReceived;
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
        totalDeclaredReceived += amount;
        if (hasStored) {
            reentryAttempts++;
            try boundary.executeAuthorizedAgentCall(_storedIntent, _storedPayload, _storedSig) {
                reentrySuccesses++;
            } catch {
                // Expected: reverts. Invariant: reentrySuccesses == 0.
            }
        }
        return true;
    }
}

/// @notice V3 base handler for Model D boundary invariants.
/// @dev Improvements over V2:
/// - Honest and malicious token modes are SEPARATE campaigns (no
///   everNonHonest gating; honest campaign enforces exact conservation
///   unconditionally).
/// - Explicit stored-intent replay action verifies NonceAlreadyUsed and
///   full state immutability on replay.
/// - Extended malicious modes: rebase (5), blacklist (6), pausable (7).
/// - Second token (honest-only) for cross-token isolation.
/// - Governance fuzz: admin transfer, stale-admin rejection, unauthorized
///   attempts, pause/unpause transitions.
/// - Allowance fuzz: exhaustion, revocation, restoration, rotation.
/// - Full rollback snapshots on the reentrant path.
/// - Precise naming: totalDeclaredReceived (not "totalReceived").
contract ModelDBoundaryHandlerV3Base is Test {
    AkmenaCore public core;
    AkmenaPolicyBoundary public boundary;
    AkmenaExecutionAuthorization public auth;
    FuzzTokenV3 public token; // primary fuzz token (modes 0-7)
    FuzzTokenV3 public token2; // secondary token, honest-only, for isolation
    FuzzAdapterV3 public adapter;
    FuzzAdapterV3 public adapter2; // dedicated adapter for token2 (isolation)
    ReentrantFuzzAdapterV3 public reentrantAdapter;

    uint256 internal constant OPERATOR1_KEY = 0x0E7A71;
    uint256 internal constant OPERATOR2_KEY = 0x0E7A72;
    uint256 internal constant AGENT1_KEY = 0xA6E171;
    uint256 internal constant AGENT2_KEY = 0xA6E172;

    address public operator1;
    address public operator2;
    address public agent1;
    address public agent2;

    // Whether this campaign allows adversarial token modes.
    bool public immutable adversarial;

    // Ghost state.
    uint256 public successfulSettlements;
    uint256 public totalPulledFromOperator;
    uint256 public totalPushedToAdapter;
    uint256 public charged1;
    uint256 public charged2;
    uint256 public dayPushed1;
    uint256 public dayPushed2;

    // Token2 isolation ghosts.
    uint256 public token2Settlements;
    uint256 public token2Pulled;
    uint256 public token2Pushed;

    // Governance ghosts.
    address public expectedAllowlistAdmin;
    address public expectedEmergencyAdmin;
    uint256 public govActionCount;
    uint256 public govRevertCount;

    // Allowance ghosts.
    uint256 public expectedAllowance1;
    uint256 public expectedAllowance2;

    // Nonce tracking.
    uint256 public nonceCounter;
    mapping(address => mapping(uint256 => bool)) public nonceUsed;
    mapping(address => uint256[]) public usedNonceList;

    // Stored successful intents for explicit replay.
    struct StoredIntent {
        AkmenaExecutionAuthorization.ExecutionIntent intent;
        bytes payload;
        bytes sig;
        address agent;
    }
    StoredIntent[] public storedIntents;
    uint256 public replayAttempts;
    uint256 public replayReverts;
    uint256 public replayStateViolations;

    // Revert atomicity.
    uint256 public revertCount;
    uint256 public revertAtomicityViolations;

    // Storage snapshots (avoid stack-too-deep).
    uint256 private _snapOpBal;
    uint256 private _snapBoundaryBal;
    uint256 private _snapAdapterBal;
    uint256 private _snapSpent;
    uint256 private _snapAllowance;
    bool private _snapNonce;

    constructor(bool _adversarial) {
        adversarial = _adversarial;

        operator1 = vm.addr(OPERATOR1_KEY);
        operator2 = vm.addr(OPERATOR2_KEY);
        agent1 = vm.addr(AGENT1_KEY);
        agent2 = vm.addr(AGENT2_KEY);

        core = new AkmenaCore();
        boundary = new AkmenaPolicyBoundary(address(core));
        auth = boundary.executionAuthorization();
        token = new FuzzTokenV3();
        token2 = new FuzzTokenV3(); // stays in honest mode (mode 0)
        adapter = new FuzzAdapterV3();
        adapter2 = new FuzzAdapterV3();
        reentrantAdapter = new ReentrantFuzzAdapterV3(address(boundary));

        // Fund operators with both tokens, approve boundary, set policies.
        token.mint(operator1, 1_000_000 ether);
        token.mint(operator2, 1_000_000 ether);
        token2.mint(operator1, 1_000_000 ether);
        token2.mint(operator2, 1_000_000 ether);

        vm.startPrank(operator1);
        token.approve(address(boundary), type(uint256).max);
        token2.approve(address(boundary), type(uint256).max);
        boundary.setAgentAssetPolicy(agent1, address(token), 100 ether, 1000 ether, false);
        boundary.setAgentAssetPolicy(agent1, address(token2), 100 ether, 1000 ether, false);
        vm.stopPrank();

        vm.startPrank(operator2);
        token.approve(address(boundary), type(uint256).max);
        token2.approve(address(boundary), type(uint256).max);
        boundary.setAgentAssetPolicy(agent2, address(token), 100 ether, 1000 ether, false);
        boundary.setAgentAssetPolicy(agent2, address(token2), 100 ether, 1000 ether, false);
        vm.stopPrank();

        expectedAllowance1 = type(uint256).max;
        expectedAllowance2 = type(uint256).max;

        // Admit tokens and adapters (deployer is allowlistAdmin).
        boundary.setStandardDebit(address(token), true);
        boundary.setStandardDebit(address(token2), true);
        boundary.setEconomicAdapter(address(token), address(adapter), true);
        boundary.setEconomicAdapter(address(token), address(reentrantAdapter), true);
        boundary.setEconomicAdapter(address(token2), address(adapter2), true);

        expectedAllowlistAdmin = boundary.allowlistAdmin();
        expectedEmergencyAdmin = boundary.emergencyAdmin();
    }

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

    function _willReset(address operator, address agent, address asset) internal view returns (bool) {
        (,,, uint256 lastReset,) = boundary.agentAssetPolicies(operator, agent, asset);
        return block.timestamp > lastReset + 1 days;
    }

    function _buildSignedIntent(
        address operator,
        address agent,
        uint256 agentKey,
        address asset,
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
            asset: asset,
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

    /// @dev Settlement parameters packed to avoid stack-too-deep.
    struct SettleParams {
        address operator;
        address agent;
        uint256 agentKey;
        address asset;
        address target;
        bytes4 selector;
        uint256 amount;
        uint256 nonce;
        bool isPair1;
    }

    /// @dev Core settlement logic shared by settle() and settleReentrant().
    /// Returns true on success. Records ghosts and stored intents.
    function _doSettle(SettleParams memory p) internal returns (bool) {
        if (nonceUsed[p.agent][p.nonce]) return false;

        (
            AkmenaExecutionAuthorization.ExecutionIntent memory intent,
            bytes memory payload,
            bytes memory sig
        ) = _buildSignedIntent(
            p.operator, p.agent, p.agentKey, p.asset, p.target,
            p.selector, p.amount, p.nonce
        );

        // Full snapshot for atomicity verification.
        _snapOpBal = ERC20(p.asset).balanceOf(p.operator);
        _snapBoundaryBal = ERC20(p.asset).balanceOf(address(boundary));
        _snapAdapterBal = ERC20(p.asset).balanceOf(p.target);
        (,, _snapSpent,,) = boundary.agentAssetPolicies(p.operator, p.agent, p.asset);
        _snapAllowance = ERC20(p.asset).allowance(p.operator, address(boundary));
        _snapNonce = auth.usedNonces(p.agent, p.nonce);
        bool willReset = _willReset(p.operator, p.agent, p.asset);

        vm.prank(p.agent);
        try boundary.executeAuthorizedAgentCall(intent, payload, sig) {
            successfulSettlements++;
            nonceUsed[p.agent][p.nonce] = true;
            usedNonceList[p.agent].push(p.nonce);

            // Store for explicit replay.
            storedIntents.push(StoredIntent({
                intent: intent,
                payload: payload,
                sig: sig,
                agent: p.agent
            }));

            uint256 pulled = _snapOpBal - ERC20(p.asset).balanceOf(p.operator);
            uint256 pushed = ERC20(p.asset).balanceOf(p.target) - _snapAdapterBal;

            // Only track primary-token ghosts for the main invariants.
            // Token2 has separate isolation ghosts.
            if (p.asset == address(token)) {
                totalPulledFromOperator += pulled;
                totalPushedToAdapter += pushed;

                // Finite allowances are consumed by transferFrom (OZ _spendAllowance
                // skips the reduction only for type(uint256).max).
                if (p.isPair1) {
                    if (expectedAllowance1 != type(uint256).max) {
                        expectedAllowance1 = pulled >= expectedAllowance1 ? 0 : expectedAllowance1 - pulled;
                    }
                } else {
                    if (expectedAllowance2 != type(uint256).max) {
                        expectedAllowance2 = pulled >= expectedAllowance2 ? 0 : expectedAllowance2 - pulled;
                    }
                }
            } else {
                token2Settlements++;
                token2Pulled += pulled;
                token2Pushed += pushed;
            }

            (,, uint256 spentAfter,,) = boundary.agentAssetPolicies(p.operator, p.agent, p.asset);
            if (p.asset == address(token)) {
                if (willReset) {
                    if (p.isPair1) {
                        charged1 = spentAfter;
                        dayPushed1 = pushed;
                    } else {
                        charged2 = spentAfter;
                        dayPushed2 = pushed;
                    }
                } else {
                    uint256 charge = spentAfter - _snapSpent;
                    if (p.isPair1) {
                        charged1 += charge;
                        dayPushed1 += pushed;
                    } else {
                        charged2 += charge;
                        dayPushed2 += pushed;
                    }
                }
            }
            return true;
        } catch {
            revertCount++;
            (,, uint256 spentAfter,,) = boundary.agentAssetPolicies(p.operator, p.agent, p.asset);
            bool atomic =
                auth.usedNonces(p.agent, p.nonce) == _snapNonce &&
                ERC20(p.asset).balanceOf(p.operator) == _snapOpBal &&
                ERC20(p.asset).balanceOf(address(boundary)) == _snapBoundaryBal &&
                ERC20(p.asset).balanceOf(p.target) == _snapAdapterBal &&
                ERC20(p.asset).allowance(p.operator, address(boundary)) == _snapAllowance &&
                spentAfter == _snapSpent;
            if (!atomic) {
                revertAtomicityViolations++;
            }
            return false;
        }
    }

    /// @dev Randomized settlement via the main adapter (primary token).
    function settle(uint256 amountSeed, uint256 nonceSeed, uint256 actorSeed) external {
        (address operator, address agent, uint256 agentKey, bool isPair1) = _actors(actorSeed);
        uint256 amount = bound(amountSeed, 0, 200 ether);
        nonceCounter++;
        uint256 nonce = nonceCounter + bound(nonceSeed, 0, 1000);
        _doSettle(SettleParams({
            operator: operator,
            agent: agent,
            agentKey: agentKey,
            asset: address(token),
            target: address(adapter),
            selector: FuzzAdapterV3.execute.selector,
            amount: amount,
            nonce: nonce,
            isPair1: isPair1
        }));
    }

    /// @dev Settlement via the reentrant adapter (with full rollback snapshots).
    function settleReentrant(uint256 amountSeed, uint256 nonceSeed) external {
        uint256 amount = bound(amountSeed, 0, 200 ether);
        nonceCounter++;
        uint256 nonce = nonceCounter + bound(nonceSeed, 0, 1000);

        if (nonceUsed[agent1][nonce]) return;

        (
            AkmenaExecutionAuthorization.ExecutionIntent memory intent,
            bytes memory payload,
            bytes memory sig
        ) = _buildSignedIntent(
            operator1, agent1, AGENT1_KEY, address(token),
            address(reentrantAdapter),
            ReentrantFuzzAdapterV3.execute.selector, amount, nonce
        );

        reentrantAdapter.storeForReentry(intent, payload, sig);

        _doSettle(SettleParams({
            operator: operator1,
            agent: agent1,
            agentKey: AGENT1_KEY,
            asset: address(token),
            target: address(reentrantAdapter),
            selector: ReentrantFuzzAdapterV3.execute.selector,
            amount: amount,
            nonce: nonce,
            isPair1: true
        }));
    }

    /// @dev Settlement with the secondary (honest-only) token for isolation testing.
    function settleToken2(uint256 amountSeed, uint256 nonceSeed, uint256 actorSeed) external {
        (address operator, address agent, uint256 agentKey, bool isPair1) = _actors(actorSeed);
        uint256 amount = bound(amountSeed, 0, 200 ether);
        nonceCounter++;
        // Use a separate nonce space to avoid collisions with token1 intents.
        uint256 nonce = nonceCounter + 1_000_000 + bound(nonceSeed, 0, 1000);
        _doSettle(SettleParams({
            operator: operator,
            agent: agent,
            agentKey: agentKey,
            asset: address(token2),
            target: address(adapter2),
            selector: FuzzAdapterV3.execute.selector,
            amount: amount,
            nonce: nonce,
            isPair1: isPair1
        }));
    }

    /// @dev EXPLICIT REPLAY: resubmit a previously successful intent.
    /// Must revert (NonceAlreadyUsed) with zero state change.
    function replayStoredIntent(uint256 seed) external {
        if (storedIntents.length == 0) return;
        uint256 idx = bound(seed, 0, storedIntents.length - 1);
        StoredIntent storage s = storedIntents[idx];

        address agent = s.agent;
        uint256 nonce = s.intent.nonce;
        address asset = s.intent.asset;
        address operator = s.intent.operator;

        // The nonce MUST already be consumed (it was a successful settlement).
        if (!auth.usedNonces(agent, nonce)) return;

        // Full snapshot.
        _snapOpBal = ERC20(asset).balanceOf(operator);
        _snapBoundaryBal = ERC20(asset).balanceOf(address(boundary));
        _snapAdapterBal = ERC20(asset).balanceOf(s.intent.target);
        (,, _snapSpent,,) = boundary.agentAssetPolicies(operator, agent, asset);
        _snapAllowance = ERC20(asset).allowance(operator, address(boundary));

        replayAttempts++;
        vm.prank(agent);
        try boundary.executeAuthorizedAgentCall(s.intent, s.payload, s.sig) {
            // Should never succeed — count as violation if it does.
            replayStateViolations++;
        } catch {
            replayReverts++;
            // Verify complete state immutability.
            (,, uint256 spentAfter,,) = boundary.agentAssetPolicies(operator, agent, asset);
            bool unchanged =
                auth.usedNonces(agent, nonce) && // still true (was true before)
                ERC20(asset).balanceOf(operator) == _snapOpBal &&
                ERC20(asset).balanceOf(address(boundary)) == _snapBoundaryBal &&
                ERC20(asset).balanceOf(s.intent.target) == _snapAdapterBal &&
                ERC20(asset).allowance(operator, address(boundary)) == _snapAllowance &&
                spentAfter == _snapSpent;
            if (!unchanged) {
                replayStateViolations++;
            }
        }
    }

    // --- Governance fuzz actions ---

    function govRemoveAdapter() external {
        govActionCount++;
        try boundary.emergencyRemoveEconomicAdapter(address(token), address(adapter)) {}
        catch { govRevertCount++; }
    }

    function govAddAdapter() external {
        govActionCount++;
        try boundary.setEconomicAdapter(address(token), address(adapter), true) {}
        catch { govRevertCount++; }
    }

    function govRemoveToken() external {
        govActionCount++;
        try boundary.emergencyRemoveStandardDebit(address(token)) {}
        catch { govRevertCount++; }
    }

    function govAddToken() external {
        govActionCount++;
        try boundary.setStandardDebit(address(token), true) {}
        catch { govRevertCount++; }
    }

    /// @dev Transfer allowlist admin to a new address (from current admin).
    function govTransferAllowlistAdmin(uint256 seed) external {
        address newAdmin = vm.addr(0xAD01 + bound(seed, 0, 100));
        if (newAdmin == address(0)) return;
        address current = boundary.allowlistAdmin();
        vm.prank(current);
        try boundary.setAllowlistAdmin(newAdmin) {
            expectedAllowlistAdmin = newAdmin;
            govActionCount++;
        } catch {
            govRevertCount++;
        }
    }

    /// @dev Transfer emergency admin to a new address (from current admin).
    function govTransferEmergencyAdmin(uint256 seed) external {
        address newAdmin = vm.addr(0xAD02 + bound(seed, 0, 100));
        if (newAdmin == address(0)) return;
        address current = boundary.emergencyAdmin();
        vm.prank(current);
        try boundary.setEmergencyAdmin(newAdmin) {
            expectedEmergencyAdmin = newAdmin;
            govActionCount++;
        } catch {
            govRevertCount++;
        }
    }

    /// @dev Stale admin (not current) attempts an admin action. Must revert.
    function govStaleAdminAttempt(uint256 seed) external {
        address stale = vm.addr(0x5A1E + bound(seed, 0, 100));
        if (stale == boundary.allowlistAdmin()) return;
        vm.prank(stale);
        try boundary.setEconomicAdapter(address(token), address(adapter), true) {
            // Should not succeed — count as violation.
            govActionCount++; // unexpected success
        } catch {
            govRevertCount++; // expected
        }
    }

    /// @dev Unauthorized address attempts emergency removal. Must revert.
    function govUnauthorizedEmergencyRemove(uint256 seed) external {
        address attacker = vm.addr(0xA77A + bound(seed, 0, 100));
        if (attacker == boundary.emergencyAdmin()) return;
        vm.prank(attacker);
        try boundary.emergencyRemoveEconomicAdapter(address(token), address(adapter)) {
            govActionCount++; // unexpected success
        } catch {
            govRevertCount++; // expected
        }
    }

    /// @dev Pause via guardian or deployer.
    function govPause(uint256 seed) external {
        address pauser = seed % 2 == 0 ? core.pauseGuardian() : core.deployer();
        if (pauser == address(0)) pauser = core.deployer();
        vm.prank(pauser);
        try core.setPaused(true) { govActionCount++; }
        catch { govRevertCount++; }
    }

    /// @dev Unpause — only deployer can succeed.
    function govUnpause(uint256 seed) external {
        address unpauser = seed % 2 == 0 ? core.deployer() : vm.addr(0x9A9A + bound(seed, 0, 100));
        vm.prank(unpauser);
        try core.setPaused(false) { govActionCount++; }
        catch { govRevertCount++; }
    }

    /// @dev Rotate pause guardian (deployer only).
    function govRotateGuardian(uint256 seed) external {
        address newGuardian = vm.addr(0x6A6A + bound(seed, 0, 100));
        vm.prank(core.deployer());
        try core.setPauseGuardian(newGuardian) { govActionCount++; }
        catch { govRevertCount++; }
    }

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
        govActionCount++;
    }

    // --- Allowance fuzz actions ---

    /// @dev Operator reduces boundary allowance to a fuzzed amount.
    function allowanceReduce(uint256 actorSeed, uint256 amountSeed) external {
        (address operator,,, bool isPair1) = _actors(actorSeed);
        uint256 amount = bound(amountSeed, 0, 500 ether);
        vm.prank(operator);
        token.approve(address(boundary), amount);
        if (isPair1) expectedAllowance1 = amount;
        else expectedAllowance2 = amount;
    }

    /// @dev Operator revokes allowance entirely (fail-closed).
    function allowanceRevoke(uint256 actorSeed) external {
        (address operator,,, bool isPair1) = _actors(actorSeed);
        vm.prank(operator);
        token.approve(address(boundary), 0);
        if (isPair1) expectedAllowance1 = 0;
        else expectedAllowance2 = 0;
    }

    /// @dev Operator restores max allowance.
    function allowanceRestore(uint256 actorSeed) external {
        (address operator,,, bool isPair1) = _actors(actorSeed);
        vm.prank(operator);
        token.approve(address(boundary), type(uint256).max);
        if (isPair1) expectedAllowance1 = type(uint256).max;
        else expectedAllowance2 = type(uint256).max;
    }

    // --- Token mode actions ---

    /// @dev Change primary token's adversarial mode. Only in adversarial campaign.
    function setTokenMode(uint8 modeSeed) external {
        if (!adversarial) return;
        uint8 m = uint8(bound(modeSeed, 0, 7));
        token.setMode(m);
    }

    /// @dev Blacklist an address on the token (mode 6).
    function tokenBlacklist(uint256 seed, bool flag) external {
        if (!adversarial) return;
        address who = bound(seed, 0, 1) == 0 ? operator1 : agent1;
        token.setBlacklisted(who, flag);
    }

    /// @dev Pause/unpause the token (mode 7).
    function tokenPause(bool p) external {
        if (!adversarial) return;
        token.setPaused(p);
    }

    function warpTime(uint256 deltaSeed) external {
        uint256 delta = bound(deltaSeed, 0, 3 days);
        if (delta == 0) return;
        vm.warp(block.timestamp + delta);
    }

    function getUsedNonces(address agent) external view returns (uint256[] memory) {
        return usedNonceList[agent];
    }

    function storedIntentCount() external view returns (uint256) {
        return storedIntents.length;
    }
}

/// @notice V3 honest-token campaign handler. Token mode changes are disabled;
/// exact conservation is enforced unconditionally by the invariant contract.
contract ModelDBoundaryHandlerV3Honest is ModelDBoundaryHandlerV3Base {
    constructor() ModelDBoundaryHandlerV3Base(false) {}
}

/// @notice V3 malicious-token campaign handler. Adversarial modes 1-7 enabled;
/// only fail-closed properties are asserted by the invariant contract.
contract ModelDBoundaryHandlerV3Malicious is ModelDBoundaryHandlerV3Base {
    constructor() ModelDBoundaryHandlerV3Base(true) {}
}
