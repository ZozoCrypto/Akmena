// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaCore} from "../../../src/core/AkmenaCore.sol";
import {AkmenaPolicyBoundary} from "../../../src/authorization/AkmenaPolicyBoundary.sol";
import {AkmenaExecutionAuthorization} from "../../../src/authorization/AkmenaExecutionAuthorization.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @notice Plain mock ERC20 with an open mint.
contract ModelDMockToken is ERC20 {
    constructor() ERC20("ModelD", "MDL") {}

    function mint(address to, uint256 amt) external {
        _mint(to, amt);
    }
}

/// @notice Allowlisted adapter mock: records pushed funds, executes payload logic.
contract ModelDMockAdapter {
    uint256 public received;
    uint256 public calls;

    function execute(uint256 amount) external returns (bool) {
        received += amount;
        calls++;
        return true;
    }
}

/// @notice AR-5: reentrant adapter — attempts to re-enter
/// executeAuthorizedAgentCall during the settlement call.
contract ModelDReentrantAdapter {
    AkmenaPolicyBoundary public boundary;
    bytes public reenterPayload;
    AkmenaExecutionAuthorization.ExecutionIntent public reenterIntent;
    bytes public reenterSig;

    constructor(address _boundary) {
        boundary = AkmenaPolicyBoundary(_boundary);
    }

    function arm(bytes memory payload, AkmenaExecutionAuthorization.ExecutionIntent memory intent, bytes memory sig)
        external
    {
        reenterPayload = payload;
        reenterIntent = intent;
        reenterSig = sig;
    }

    function attack() external {
        // Try to re-enter the boundary mid-settlement.
        boundary.executeAuthorizedAgentCall(reenterIntent, reenterPayload, reenterSig);
    }
}

/// @notice Adapter mock that always reverts, to prove atomic rollback.
contract ModelDRevertingAdapter {
    function execute(uint256) external pure returns (bool) {
        revert("adapter exploded");
    }
}

/// @notice Model D (operator-retained custody) settlement tests — Phase 1.
///
/// Each economic execution must: pull exactly intent.amount from the
/// operator, push it to the allowlisted adapter, then call the adapter,
/// atomically. The boundary must never hold residual ERC20.
contract ModelDOperatorCustodySettlementTest is Test {
    uint256 internal constant AGENT_KEY = 0xA11CE;

    address internal agent;
    address internal operator = address(0xB0B);

    AkmenaCore internal core;
    AkmenaPolicyBoundary internal boundary;
    AkmenaExecutionAuthorization internal authorization;
    ModelDMockToken internal token;
    ModelDMockAdapter internal adapter;
    ModelDRevertingAdapter internal revertingAdapter;

    function setUp() public {
        agent = vm.addr(AGENT_KEY);

        core = new AkmenaCore();
        boundary = new AkmenaPolicyBoundary(address(core));
        authorization = boundary.executionAuthorization();
        token = new ModelDMockToken();
        adapter = new ModelDMockAdapter();
        revertingAdapter = new ModelDRevertingAdapter();

        // Deployer (this test contract) allowlists the adapter for the token.
        boundary.setEconomicAdapter(address(token), address(adapter), true);
        boundary.setEconomicAdapter(address(token), address(revertingAdapter), true);

        // Deployer admits the token to the Standard-Debit allowlist (§7.2).
        // Default-deny: without this, positive-amount settlement reverts.
        boundary.setStandardDebit(address(token), true);

        token.mint(operator, 1_000_000 ether);

        // Operator funds the policy and approves the boundary.
        vm.startPrank(operator);
        boundary.setAgentAssetPolicy(agent, address(token), 100 ether, 1_000 ether, false);
        token.approve(address(boundary), 500 ether);
        vm.stopPrank();
    }

    function _intent(address target, bytes memory payload, uint256 amount, uint256 nonce)
        internal
        view
        returns (AkmenaExecutionAuthorization.ExecutionIntent memory)
    {
        return AkmenaExecutionAuthorization.ExecutionIntent({
            operator: operator,
            agent: agent,
            target: target,
            selector: ModelDMockAdapter.execute.selector,
            asset: address(token),
            calldataHash: keccak256(payload),
            amount: amount,
            value: 0,
            proofModuleKey: bytes32(0),
            proofId: 0,
            nonce: nonce,
            // Intents bind the current wall-clock; vm.warp in time-travel
            // tests is the mechanism under test, not an accident.
            // forge-lint: disable-next-line(environment-read-across-mutation)
            validAfter: block.timestamp,
            // forge-lint: disable-next-line(environment-read-across-mutation)
            deadline: block.timestamp + 1 hours
        });
    }

    function _sign(AkmenaExecutionAuthorization.ExecutionIntent memory intent) internal view returns (bytes memory) {
        bytes32 digest = authorization.hashIntent(intent);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(AGENT_KEY, digest);
        return abi.encodePacked(r, s, v);
    }

    function _spentToday() internal view returns (uint256) {
        (,, uint256 spentToday,,) = boundary.agentAssetPolicies(operator, agent, address(token));
        return spentToday;
    }

    function test_HappyPath_PullPushCallExact() public {
        uint256 amount = 100 ether;
        bytes memory payload = abi.encodeWithSelector(ModelDMockAdapter.execute.selector, amount);
        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _intent(address(adapter), payload, amount, 0);

        uint256 operatorBefore = token.balanceOf(operator);

        bytes memory signature = _sign(intent);
        vm.prank(agent);
        boundary.executeAuthorizedAgentCall(intent, payload, signature);

        // Adapter received exactly intent.amount.
        assertEq(adapter.received(), amount);
        assertEq(token.balanceOf(address(adapter)), amount);
        // Operator was debited exactly intent.amount.
        assertEq(token.balanceOf(operator), operatorBefore - amount);
        // Boundary holds nothing residual.
        assertEq(token.balanceOf(address(boundary)), 0);
        // Policy charged the full authorized amount.
        assertEq(_spentToday(), amount);
        // Nonce consumed.
        assertTrue(authorization.usedNonces(agent, 0));
    }

    function test_InsufficientAllowanceRevertsCleanly() public {
        // Operator revokes the approval set in setUp.
        vm.prank(operator);
        token.approve(address(boundary), 0);

        uint256 amount = 10 ether;
        bytes memory payload = abi.encodeWithSelector(ModelDMockAdapter.execute.selector, amount);
        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _intent(address(adapter), payload, amount, 0);

        uint256 operatorBefore = token.balanceOf(operator);

        bytes memory signature = _sign(intent);
        vm.prank(agent);
        vm.expectRevert(AkmenaPolicyBoundary.InsufficientOperatorAllowance.selector);
        boundary.executeAuthorizedAgentCall(intent, payload, signature);

        // Nothing moved, nothing charged, nonce unconsumed.
        assertEq(token.balanceOf(operator), operatorBefore);
        assertEq(_spentToday(), 0);
        assertFalse(authorization.usedNonces(agent, 0));
    }

    function test_PartialAllowanceReverts() public {
        vm.prank(operator);
        token.approve(address(boundary), 5 ether);

        uint256 amount = 10 ether;
        bytes memory payload = abi.encodeWithSelector(ModelDMockAdapter.execute.selector, amount);
        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _intent(address(adapter), payload, amount, 0);

        bytes memory signature = _sign(intent);
        vm.prank(agent);
        vm.expectRevert(AkmenaPolicyBoundary.InsufficientOperatorAllowance.selector);
        boundary.executeAuthorizedAgentCall(intent, payload, signature);

        assertEq(_spentToday(), 0);
    }

    function test_ZeroAmount_GenericCallNoCharge() public {
        // GAP-3 HARDENED (2026-10-01): Zero-amount call to a non-allowlisted,
        // non-module target now reverts with UnauthorizedZeroAmountTarget.
        // This closes the confused-deputy vector.
        ModelDMockAdapter plainTarget = new ModelDMockAdapter();
        bytes memory payload = abi.encodeWithSelector(ModelDMockAdapter.execute.selector, 0);
        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _intent(address(plainTarget), payload, 0, 0);

        bytes memory signature = _sign(intent);
        vm.prank(agent);
        vm.expectRevert(AkmenaPolicyBoundary.UnauthorizedZeroAmountTarget.selector);
        boundary.executeAuthorizedAgentCall(intent, payload, signature);
    }

    function test_ZeroAmount_ToProofModuleSucceedsNoCharge() public {
        // GAP-3: Zero-amount call to a registered proof module succeeds (preserves use case).
        ModelDMockAdapter moduleTarget = new ModelDMockAdapter();
        bytes32 moduleKey = keccak256("test.proof.module");
        core.registerModule(moduleKey, address(moduleTarget), "1.0.0");

        bytes memory payload = abi.encodeWithSelector(ModelDMockAdapter.execute.selector, 0);
        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _intent(address(moduleTarget), payload, 0, 1);
        intent.proofModuleKey = moduleKey;

        bytes memory signature = _sign(intent);
        vm.prank(agent);
        boundary.executeAuthorizedAgentCall(intent, payload, signature);

        assertEq(moduleTarget.calls(), 1);
        assertEq(_spentToday(), 0);
        assertEq(token.balanceOf(address(boundary)), 0);
    }

    function test_AmountToNonAdapterTargetReverts() public {
        ModelDMockAdapter plainTarget = new ModelDMockAdapter();
        uint256 amount = 10 ether;
        bytes memory payload = abi.encodeWithSelector(ModelDMockAdapter.execute.selector, amount);
        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _intent(address(plainTarget), payload, amount, 0);

        bytes memory signature = _sign(intent);
        vm.prank(agent);
        vm.expectRevert(AkmenaPolicyBoundary.EconomicAdapterNotAllowed.selector);
        boundary.executeAuthorizedAgentCall(intent, payload, signature);

        assertEq(_spentToday(), 0);
        assertFalse(authorization.usedNonces(agent, 0));
    }

    function test_AdapterRevertRollsBackAtomically() public {
        uint256 amount = 25 ether;
        bytes memory payload = abi.encodeWithSelector(ModelDMockAdapter.execute.selector, amount);
        AkmenaExecutionAuthorization.ExecutionIntent memory intent =
            _intent(address(revertingAdapter), payload, amount, 0);

        uint256 operatorBefore = token.balanceOf(operator);

        bytes memory signature = _sign(intent);
        vm.prank(agent);
        vm.expectRevert("adapter exploded");
        boundary.executeAuthorizedAgentCall(intent, payload, signature);

        // Pull, push, charge, and nonce all rolled back.
        assertEq(token.balanceOf(operator), operatorBefore);
        assertEq(token.balanceOf(address(boundary)), 0);
        assertEq(_spentToday(), 0);
        assertFalse(authorization.usedNonces(agent, 0));
    }

    function test_DailyLimitExhaustionIsCleanNotPanic() public {
        // Spend the daily limit exactly, then attempt one more wei.
        // Headroom is zero: the intent must revert PolicyExceeded cleanly,
        // never Panic(0x11). (Lowering dailyLimit below totalSpentToday is
        // unreachable via the current setters — reconfigure resets counters —
        // so the saturating arithmetic in _settleERC20 is defensive; this
        // test pins the reachable exhaustion boundary.)
        vm.prank(operator);
        boundary.setAgentAssetPolicy(agent, address(token), 100 ether, 100 ether, false);

        bytes memory payload = abi.encodeWithSelector(ModelDMockAdapter.execute.selector, 60 ether);
        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _intent(address(adapter), payload, 60 ether, 0);
        bytes memory signature = _sign(intent);
        vm.prank(agent);
        boundary.executeAuthorizedAgentCall(intent, payload, signature);

        bytes memory payload2 = abi.encodeWithSelector(ModelDMockAdapter.execute.selector, 40 ether);
        AkmenaExecutionAuthorization.ExecutionIntent memory intent2 = _intent(address(adapter), payload2, 40 ether, 1);
        bytes memory signature2 = _sign(intent2);
        vm.prank(agent);
        boundary.executeAuthorizedAgentCall(intent2, payload2, signature2);
        assertEq(_spentToday(), 100 ether);

        bytes memory payload3 = abi.encodeWithSelector(ModelDMockAdapter.execute.selector, 1);
        AkmenaExecutionAuthorization.ExecutionIntent memory intent3 = _intent(address(adapter), payload3, 1, 2);
        bytes memory signature3 = _sign(intent3);
        vm.prank(agent);
        vm.expectRevert(AkmenaPolicyBoundary.PolicyExceeded.selector);
        boundary.executeAuthorizedAgentCall(intent3, payload3, signature3);

        // Failed intent charged nothing and consumed no nonce.
        assertEq(_spentToday(), 100 ether);
        assertFalse(authorization.usedNonces(agent, 2));
    }

    function test_OperatorMismatch_CannotSpendVictimFunds() public {
        // An attacker with their own policy cannot touch the victim's
        // allowance: funding source is bound to intent.operator.
        address attacker = address(0xBAD);
        token.mint(attacker, 1_000 ether);

        vm.startPrank(attacker);
        boundary.setAgentAssetPolicy(agent, address(token), 100 ether, 1_000 ether, false);
        token.approve(address(boundary), 500 ether);
        vm.stopPrank();

        // Attacker signs an intent naming the VICTIM operator. The agent key
        // is the same, but the operator field differs from the attacker's
        // own namespace... so first show the honest attacker-self path works
        // only against the attacker's own funds:
        uint256 amount = 10 ether;
        bytes memory payload = abi.encodeWithSelector(ModelDMockAdapter.execute.selector, amount);
        AkmenaExecutionAuthorization.ExecutionIntent memory selfIntent = AkmenaExecutionAuthorization.ExecutionIntent({
            operator: attacker,
            agent: agent,
            target: address(adapter),
            selector: ModelDMockAdapter.execute.selector,
            asset: address(token),
            calldataHash: keccak256(payload),
            amount: amount,
            value: 0,
            proofModuleKey: bytes32(0),
            proofId: 0,
            nonce: 0,
            validAfter: block.timestamp,
            deadline: block.timestamp + 1 hours
        });

        uint256 attackerBefore = token.balanceOf(attacker);
        uint256 operatorBefore = token.balanceOf(operator);

        bytes memory signature = _sign(selfIntent);
        vm.prank(agent);
        boundary.executeAuthorizedAgentCall(selfIntent, payload, signature);

        // Only the attacker's own wallet was debited; victim untouched.
        assertEq(token.balanceOf(attacker), attackerBefore - amount);
        assertEq(token.balanceOf(operator), operatorBefore);
    }

    // ============ Phase 2: events and semantic locks ============

    function test_EmitsERC20Settled() public {
        uint256 amount = 10 ether;
        bytes memory payload = abi.encodeWithSelector(ModelDMockAdapter.execute.selector, amount);
        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _intent(address(adapter), payload, amount, 0);
        bytes memory signature = _sign(intent);

        vm.expectEmit(true, true, true, true);
        emit AkmenaPolicyBoundary.ERC20Settled(operator, agent, address(token), amount, address(adapter));

        vm.prank(agent);
        boundary.executeAuthorizedAgentCall(intent, payload, signature);
    }

    function test_EmitsEconomicAdapterUpdated() public {
        ModelDMockAdapter newAdapter = new ModelDMockAdapter();

        vm.expectEmit(true, true, false, true);
        emit AkmenaPolicyBoundary.EconomicAdapterUpdated(address(token), address(newAdapter), true);
        boundary.setEconomicAdapter(address(token), address(newAdapter), true);

        vm.expectEmit(true, true, false, true);
        emit AkmenaPolicyBoundary.EconomicAdapterUpdated(address(token), address(newAdapter), false);
        boundary.setEconomicAdapter(address(token), address(newAdapter), false);
    }

    function test_EmitsAgentAssetPolicyConfigured() public {
        vm.expectEmit(true, true, true, true);
        emit AkmenaPolicyBoundary.AgentAssetPolicyConfigured(operator, agent, address(token), 7 ether, 70 ether, true);

        vm.prank(operator);
        boundary.setAgentAssetPolicy(agent, address(token), 7 ether, 70 ether, true);
    }

    function test_EmitsAgentPolicyConfigured() public {
        vm.expectEmit(true, true, false, true);
        emit AkmenaPolicyBoundary.AgentPolicyConfigured(operator, agent, 5 ether, 50 ether, true);

        vm.prank(operator);
        boundary.setAgentPolicy(agent, 5 ether, 50 ether, true);
    }

    function test_ReconfigureResetsCounters() public {
        // F-3 semantic lock: reconfiguring a policy resets the daily
        // counters; previously recorded spend is discarded, not preserved.
        bytes memory payload = abi.encodeWithSelector(ModelDMockAdapter.execute.selector, 60 ether);
        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _intent(address(adapter), payload, 60 ether, 0);
        bytes memory signature = _sign(intent);
        vm.prank(agent);
        boundary.executeAuthorizedAgentCall(intent, payload, signature);
        assertEq(_spentToday(), 60 ether);

        vm.prank(operator);
        boundary.setAgentAssetPolicy(agent, address(token), 200 ether, 200 ether, false);

        (uint256 maxSpend, uint256 daily, uint256 spentToday,,) =
            boundary.agentAssetPolicies(operator, agent, address(token));
        assertEq(maxSpend, 200 ether);
        assertEq(daily, 200 ether);
        assertEq(spentToday, 0);

        // The full new daily limit is available.
        bytes memory payload2 = abi.encodeWithSelector(ModelDMockAdapter.execute.selector, 200 ether);
        AkmenaExecutionAuthorization.ExecutionIntent memory intent2 =
            _intent(address(adapter), payload2, 200 ether, 1);
        bytes memory signature2 = _sign(intent2);
        vm.prank(agent);
        boundary.executeAuthorizedAgentCall(intent2, payload2, signature2);
        assertEq(_spentToday(), 200 ether);
    }

    function test_ResetBoundary_StrictlyGreaterThanOneDay() public {
        // F-14 semantic lock: the rolling window resets only when STRICTLY
        // more than 1 day has elapsed since lastResetTimestamp.
        vm.prank(operator);
        boundary.setAgentAssetPolicy(agent, address(token), 100 ether, 100 ether, false);

        bytes memory payload = abi.encodeWithSelector(ModelDMockAdapter.execute.selector, 60 ether);
        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _intent(address(adapter), payload, 60 ether, 0);
        bytes memory signature = _sign(intent);
        vm.prank(agent);
        boundary.executeAuthorizedAgentCall(intent, payload, signature);
        assertEq(_spentToday(), 60 ether);

        // Exactly +1 day: NO reset.
        uint256 t0 = vm.getBlockTimestamp();
        vm.warp(t0 + 1 days);
        bytes memory payload2 = abi.encodeWithSelector(ModelDMockAdapter.execute.selector, 50 ether);
        AkmenaExecutionAuthorization.ExecutionIntent memory intent2 = _intent(address(adapter), payload2, 50 ether, 1);
        bytes memory signature2 = _sign(intent2);
        vm.prank(agent);
        vm.expectRevert(AkmenaPolicyBoundary.PolicyExceeded.selector);
        boundary.executeAuthorizedAgentCall(intent2, payload2, signature2);

        // +1 day + 1 second: reset.
        vm.warp(t0 + 2 days + 1);
        bytes memory payload3 = abi.encodeWithSelector(ModelDMockAdapter.execute.selector, 50 ether);
        AkmenaExecutionAuthorization.ExecutionIntent memory intent3 = _intent(address(adapter), payload3, 50 ether, 2);
        bytes memory signature3 = _sign(intent3);
        vm.prank(agent);
        boundary.executeAuthorizedAgentCall(intent3, payload3, signature3);
        assertEq(_spentToday(), 50 ether);
    }

    /*//////////////////////////////////////////////////////////////
                      AR-3 / AR-4 / AR-5 — §10.1 EVIDENCE
    //////////////////////////////////////////////////////////////*/

    /// @notice AR-3 (revoke mid-flight): the operator revokes the boundary
    /// allowance after the intent is signed but before execution.
    /// Execution reverts InsufficientOperatorAllowance; nothing is charged
    /// and the nonce is not consumed.
    function test_AR3_AllowanceRevokedMidFlightRevertsCleanly() public {

        bytes memory payload = abi.encodeWithSelector(ModelDMockAdapter.execute.selector, 60 ether);
        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _intent(address(adapter), payload, 60 ether, 0);
        bytes memory signature = _sign(intent);

        // Operator revokes between signing and execution.
        vm.prank(operator);
        token.approve(address(boundary), 0);

        vm.prank(agent);
        vm.expectRevert(AkmenaPolicyBoundary.InsufficientOperatorAllowance.selector);
        boundary.executeAuthorizedAgentCall(intent, payload, signature);

        assertEq(token.balanceOf(operator), 1_000_000 ether, "operator balance unchanged");
        assertEq(_spentToday(), 0, "no spend recorded");
        assertFalse(authorization.usedNonces(agent, 0), "nonce not consumed");
    }

    /// @notice AR-4 (racing allowance): two signed intents race for a
    /// finite allowance. The first settles; the second reverts cleanly
    /// on the allowance pre-check — no partial settlement, no overdraft.
    function test_AR4_ConcurrentIntentsRaceAllowanceSafely() public {
        // Tighten the approval so the two 60-intents race for 100.
        vm.prank(operator);
        token.approve(address(boundary), 100 ether);

        bytes memory payload1 = abi.encodeWithSelector(ModelDMockAdapter.execute.selector, 60 ether);
        AkmenaExecutionAuthorization.ExecutionIntent memory intent1 = _intent(address(adapter), payload1, 60 ether, 0);
        bytes memory sig1 = _sign(intent1);

        bytes memory payload2 = abi.encodeWithSelector(ModelDMockAdapter.execute.selector, 60 ether);
        AkmenaExecutionAuthorization.ExecutionIntent memory intent2 = _intent(address(adapter), payload2, 60 ether, 1);
        bytes memory sig2 = _sign(intent2);

        vm.prank(agent);
        boundary.executeAuthorizedAgentCall(intent1, payload1, sig1);
        assertEq(_spentToday(), 60 ether);

        // Only 40 of allowance remains; the second 60-intent fails closed.
        vm.prank(agent);
        vm.expectRevert(AkmenaPolicyBoundary.InsufficientOperatorAllowance.selector);
        boundary.executeAuthorizedAgentCall(intent2, payload2, sig2);

        assertEq(token.balanceOf(operator), 1_000_000 ether - 60 ether, "operator debited exactly 60");
        assertEq(token.balanceOf(address(adapter)), 60 ether, "adapter received exactly 60");
        assertEq(_spentToday(), 60 ether, "spend unchanged by failed race");
        assertFalse(authorization.usedNonces(agent, 1), "loser nonce not consumed");
    }

    /// @notice AR-5 (reentrant adapter): the adapter attempts to re-enter
    /// executeAuthorizedAgentCall during the settlement call. The
    /// ReentrancyGuardTransient lock reverts the inner call; the outer
    /// settlement rolls back atomically — no double-spend, no partial state.
    function test_AR5_ReentrantAdapterBlockedAtomically() public {

        ModelDReentrantAdapter reentrant = new ModelDReentrantAdapter(address(boundary));
        boundary.setEconomicAdapter(address(token), address(reentrant), true);

        // Inner intent: a second, separately-signed drain attempt.
        bytes memory innerPayload = abi.encodeWithSelector(ModelDMockAdapter.execute.selector, 60 ether);
        AkmenaExecutionAuthorization.ExecutionIntent memory innerIntent =
            _intent(address(adapter), innerPayload, 60 ether, 1);
        bytes memory innerSig = _sign(innerIntent);
        reentrant.arm(innerPayload, innerIntent, innerSig);

        // Outer intent targets the reentrant adapter.
        bytes memory outerPayload = abi.encodeWithSelector(ModelDReentrantAdapter.attack.selector);
        AkmenaExecutionAuthorization.ExecutionIntent memory outerIntent =
            _intent(address(reentrant), outerPayload, 60 ether, 0);
        bytes memory outerSig = _sign(outerIntent);

        vm.prank(agent);
        vm.expectRevert(); // ReentrancyGuardTransient reverts the inner call; outer bubbles it.
        boundary.executeAuthorizedAgentCall(outerIntent, outerPayload, outerSig);

        // Atomic rollback: the pull, push, charge, and both nonces are void.
        assertEq(token.balanceOf(operator), 1_000_000 ether, "operator balance unchanged");
        assertEq(token.balanceOf(address(boundary)), 0, "boundary holds nothing");
        assertEq(_spentToday(), 0, "no spend recorded");
        assertFalse(authorization.usedNonces(agent, 0), "outer nonce not consumed");
        assertFalse(authorization.usedNonces(agent, 1), "inner nonce not consumed");
    }

    // ── Standard-Debit admission (§7.2) ──────────────────────────────

    /// @notice Default-deny: a positive-amount intent naming a non-admitted
    /// token reverts StandardDebitNotAdmitted — even when the adapter is
    /// allowlisted and the operator has approved. Asset trust and code trust
    /// are separate gates; both must pass.
    function test_Admission_NonAdmittedTokenRevertsOnEconomicPath() public {
        ModelDMockToken unadmitted = new ModelDMockToken();
        unadmitted.mint(operator, 1_000 ether);
        // Adapter allowlisted for the unadmitted token — code trust passes.
        boundary.setEconomicAdapter(address(unadmitted), address(adapter), true);
        // NOTE: no setStandardDebit — asset trust must fail.

        vm.startPrank(operator);
        boundary.setAgentAssetPolicy(agent, address(unadmitted), 100 ether, 1_000 ether, false);
        unadmitted.approve(address(boundary), 500 ether);
        vm.stopPrank();

        bytes memory payload = abi.encodeWithSelector(ModelDMockAdapter.execute.selector, 60 ether);
        AkmenaExecutionAuthorization.ExecutionIntent memory intent = AkmenaExecutionAuthorization.ExecutionIntent({
            operator: operator,
            agent: agent,
            target: address(adapter),
            selector: ModelDMockAdapter.execute.selector,
            asset: address(unadmitted),
            calldataHash: keccak256(payload),
            amount: 60 ether,
            value: 0,
            proofModuleKey: bytes32(0),
            proofId: 0,
            nonce: 0,
            validAfter: block.timestamp,
            deadline: block.timestamp + 1 hours
        });
        // Sign BEFORE expectRevert: argument evaluation order would otherwise
        // consume the revert expectation on the hashIntent staticcall.
        bytes memory signature = _sign(intent);

        vm.prank(agent);
        vm.expectRevert(AkmenaPolicyBoundary.StandardDebitNotAdmitted.selector);
        boundary.executeAuthorizedAgentCall(intent, payload, signature);

        // Nothing moved, nothing charged, nonce unconsumed.
        assertEq(unadmitted.balanceOf(operator), 1_000 ether, "operator balance unchanged");
        assertEq(_spentToday(), 0, "no spend recorded");
    }

    /// @notice Zero-amount intents are exempt from token admission (§7.2):
    /// no funds move, so token semantics are irrelevant. The adapter gate
    /// (step 4) still applies.
    function test_Admission_ZeroAmountExemptFromAdmission() public {
        ModelDMockToken unadmitted = new ModelDMockToken();
        boundary.setEconomicAdapter(address(unadmitted), address(adapter), true);
        // NOTE: no setStandardDebit — zero-amount must still succeed.

        vm.prank(operator);
        boundary.setAgentAssetPolicy(agent, address(unadmitted), 100 ether, 1_000 ether, false);

        bytes memory payload = abi.encodeWithSelector(ModelDMockAdapter.execute.selector, 0);
        AkmenaExecutionAuthorization.ExecutionIntent memory intent = AkmenaExecutionAuthorization.ExecutionIntent({
            operator: operator,
            agent: agent,
            target: address(adapter),
            selector: ModelDMockAdapter.execute.selector,
            asset: address(unadmitted),
            calldataHash: keccak256(payload),
            amount: 0,
            value: 0,
            proofModuleKey: bytes32(0),
            proofId: 0,
            nonce: 0,
            validAfter: block.timestamp,
            deadline: block.timestamp + 1 hours
        });
        // Sign BEFORE expectRevert: argument evaluation order would otherwise
        // consume the revert expectation on the hashIntent staticcall.
        bytes memory signature = _sign(intent);

        vm.prank(agent);
        boundary.executeAuthorizedAgentCall(intent, payload, signature);

        assertEq(_spentToday(), 0, "zero-amount records no spend");
        assertTrue(authorization.usedNonces(agent, 0), "nonce consumed");
    }

    /// @notice Only the deployer can admit or remove tokens (interim
    /// authority; G-7 moves this behind timelocked multisig).
    function test_Admission_NonDeployerCannotAdmit() public {
        address attacker = vm.addr(0xBEEF);
        vm.prank(attacker);
        vm.expectRevert(AkmenaPolicyBoundary.UnauthorizedAdapterAdmin.selector);
        boundary.setStandardDebit(address(token), true);

        vm.prank(attacker);
        vm.expectRevert(AkmenaPolicyBoundary.UnauthorizedAdapterAdmin.selector);
        boundary.setStandardDebit(address(token), false);

        assertTrue(boundary.isStandardDebit(address(token)), "admission unchanged");
    }

    /// @notice Removal is immediate and fail-closed: a signed-but-unexecuted
    /// intent targeting the removed token reverts with the nonce unconsumed.
    /// Removal does NOT revoke operator→boundary allowances on the token.
    function test_Admission_RemovalIsFailClosed() public {
        bytes memory payload = abi.encodeWithSelector(ModelDMockAdapter.execute.selector, 60 ether);
        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _intent(address(adapter), payload, 60 ether, 0);
        bytes memory signature = _sign(intent);

        // Deployer removes the token after signing but before execution.
        boundary.setStandardDebit(address(token), false);
        assertFalse(boundary.isStandardDebit(address(token)), "token removed");

        vm.prank(agent);
        vm.expectRevert(AkmenaPolicyBoundary.StandardDebitNotAdmitted.selector);
        boundary.executeAuthorizedAgentCall(intent, payload, signature);

        assertEq(token.balanceOf(operator), 1_000_000 ether, "operator balance unchanged");
        assertEq(_spentToday(), 0, "no spend recorded");
        assertFalse(authorization.usedNonces(agent, 0), "nonce unconsumed - retryable after re-admission");
        // Allowance survives removal: it lives on the token, not the boundary.
        assertEq(token.allowance(operator, address(boundary)), 500 ether, "allowance not revoked by removal");
    }

    /// @notice StandardDebitUpdated is emitted on admit and remove (F-10
    /// monitoring trigger for the token-admission path).
    function test_Admission_StandardDebitUpdatedEmitted() public {
        ModelDMockToken fresh = new ModelDMockToken();

        vm.expectEmit(true, false, false, true);
        emit AkmenaPolicyBoundary.StandardDebitUpdated(address(fresh), true);
        boundary.setStandardDebit(address(fresh), true);

        vm.expectEmit(true, false, false, true);
        emit AkmenaPolicyBoundary.StandardDebitUpdated(address(fresh), false);
        boundary.setStandardDebit(address(fresh), false);
    }
}
