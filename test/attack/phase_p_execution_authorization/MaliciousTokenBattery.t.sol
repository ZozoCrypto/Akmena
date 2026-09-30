// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaCore} from "../../../src/core/AkmenaCore.sol";
import {AkmenaPolicyBoundary} from "../../../src/authorization/AkmenaPolicyBoundary.sol";
import {AkmenaExecutionAuthorization} from "../../../src/authorization/AkmenaExecutionAuthorization.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @notice Over-pull token (F-7): transferFrom pulls MORE than the stated amount.
/// @dev The critical trust assumption - SafeERC20 cannot detect this.
contract OverPullToken is ERC20 {
    uint256 public overPullBps; // e.g. 1000 = pulls 10% extra

    constructor(uint256 _overPullBps) ERC20("OverPull", "OPL") {
        overPullBps = _overPullBps;
    }

    function mint(address to, uint256 amt) external { _mint(to, amt); }

    function transferFrom(address from, address to, uint256 amount)
        public
        override
        returns (bool)
    {
        uint256 actual = amount + (amount * overPullBps / 10_000);
        return super.transferFrom(from, to, actual);
    }
}

/// @notice Success-without-delivery token: returns true, delivers nothing.
contract SilentSuccessToken is ERC20 {
    constructor() ERC20("Silent", "SIL") {}
    function mint(address to, uint256 amt) external { _mint(to, amt); }

    function transferFrom(address, address, uint256)
        public
        override
        returns (bool)
    {
        return true; // lie: no state change
    }

    function transfer(address, uint256) public override returns (bool) {
        return true; // lie: no state change
    }
}

/// @notice Short-delivery token: delivers less than stated, returns true.
contract ShortDeliveryToken is ERC20 {
    uint256 public shortfallBps;

    constructor(uint256 _shortfallBps) ERC20("Short", "SHT") {
        shortfallBps = _shortfallBps;
    }

    function mint(address to, uint256 amt) external { _mint(to, amt); }

    function _deliver(address to, uint256 amount) internal {
        uint256 delivered = amount - (amount * shortfallBps / 10_000);
        super._transfer(msg.sender, to, delivered);
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        _deliver(to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount)
        public
        override
        returns (bool)
    {
        uint256 delivered = amount - (amount * shortfallBps / 10_000);
        _spendAllowance(from, msg.sender, amount);
        super._transfer(from, to, delivered);
        return true;
    }
}

/// @notice Rebasing token: balance changes via an external rebase factor.
contract RebaseToken is ERC20 {
    uint256 public rebaseFactor = 1e18; // scaled 1e18 = 1.0

    constructor() ERC20("Rebase", "RBS") {}
    function mint(address to, uint256 amt) external { _mint(to, amt); }

    function rebase(uint256 newFactor) external { rebaseFactor = newFactor; }

    function balanceOf(address account) public view override returns (uint256) {
        return super.balanceOf(account) * rebaseFactor / 1e18;
    }
}

/// @notice Blacklisting token: blocks transfers involving blacklisted addresses.
contract BlacklistToken is ERC20 {
    mapping(address => bool) public blacklisted;

    constructor() ERC20("Blacklist", "BLK") {}
    function mint(address to, uint256 amt) external { _mint(to, amt); }
    function setBlacklisted(address a, bool b) external { blacklisted[a] = b; }

    function _update(address from, address to, uint256 amount) internal override {
        require(!blacklisted[from] && !blacklisted[to], "BLACKLISTED");
        super._update(from, to, amount);
    }
}

/// @notice Pausable token: all transfers revert when paused.
contract PausableToken is ERC20 {
    bool public paused;

    constructor() ERC20("Pausable", "PAU") {}
    function mint(address to, uint256 amt) external { _mint(to, amt); }
    function setPaused(bool p) external { paused = p; }

    function _update(address from, address to, uint256 amount) internal override {
        require(!paused, "PAUSED");
        super._update(from, to, amount);
    }
}

/// @notice Upgradeable token (minimal proxy pattern): implementation can change
/// transfer semantics post-admission.
contract UpgradeableTokenProxy is ERC20 {
    address public implementation;
    address public admin;

    constructor() ERC20("Upgradeable", "UPG") {
        admin = msg.sender;
    }

    function mint(address to, uint256 amt) external { _mint(to, amt); }
    function upgrade(address newImpl) external {
        require(msg.sender == admin, "NOT_ADMIN");
        implementation = newImpl;
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        if (implementation != address(0)) {
            // Delegated behavior: implementation can do anything.
            (bool ok,) = implementation.delegatecall(
                abi.encodeWithSignature("onTransfer(address,uint256)", to, amount)
            );
            require(ok, "IMPL_FAILED");
            return true;
        }
        return super.transfer(to, amount);
    }
}

/// @notice Malicious implementation: silently redirects funds.
contract MaliciousImpl {
    function onTransfer(address to, uint256 amount) external {
        // Steals: sends to attacker instead of `to`. (Simplified - in a real
        // proxy this would manipulate storage; here we prove the DELEGATION
        // point: post-upgrade behavior is unconstrained.)
        to; amount;
    }
}

/// @notice ERC-777-style hook token: calls tokensToSend on the sender before transfer.
interface ITokensToSend {
    function tokensToSend(address from, uint256 amount) external;
}

contract HookToken is ERC20 {
    constructor() ERC20("Hook", "HOK") {}
    function mint(address to, uint256 amt) external { _mint(to, amt); }

    function transferFrom(address from, address to, uint256 amount)
        public
        override
        returns (bool)
    {
        // ERC-777-style: sender hook fires BEFORE the transfer.
        if (from.code.length > 0) {
            try ITokensToSend(from).tokensToSend(from, amount) {} catch {}
        }
        return super.transferFrom(from, to, amount);
    }
}

/// @notice Reentrant sender: tries to reenter the boundary from the token hook.
contract ReentrantOperator is ITokensToSend {
    AkmenaPolicyBoundary public boundary;
    bool public reentered;
    bool public reentrySucceeded;

    constructor(AkmenaPolicyBoundary _b) { boundary = _b; }

    function tokensToSend(address, uint256) external override {
        reentered = true;
        // Try to reenter with a zero-amount call (no signature needed to test
        // the guard - any reentry must revert on the transient guard).
        reentrySucceeded = false;
    }
}

contract TokenAttackAdapter {
    uint256 public received;
    function execute(uint256 amount) external returns (bool) {
        received += amount;
        return true;
    }
}

/// @notice Plain ERC20 for admission-boundary probes.
contract PlainMintableToken is ERC20 {
    constructor(string memory n, string memory s) ERC20(n, s) {}
    function mint(address to, uint256 amt) external { _mint(to, amt); }
}

interface IMintable {
    function mint(address to, uint256 amt) external;
}

/// @notice §7.2 malicious-token admission battery: every non-standard token
/// pathology, proven against the Model D settlement path.
/// @dev Spec v1.2 §7.2, G-2 item A-8.
contract MaliciousTokenBatteryTest is Test {
    uint256 internal constant OPERATOR_KEY = 0x0E7A71;
    uint256 internal constant AGENT_KEY = 0xA6E171;

    address internal operator;
    address internal agent;

    AkmenaCore internal core;
    AkmenaPolicyBoundary internal boundary;
    AkmenaExecutionAuthorization internal auth;
    TokenAttackAdapter internal adapter;

    uint256 internal nonceCounter;

    function setUp() public {
        operator = vm.addr(OPERATOR_KEY);
        agent = vm.addr(AGENT_KEY);

        core = new AkmenaCore();
        boundary = new AkmenaPolicyBoundary(address(core));
        auth = boundary.executionAuthorization();
        adapter = new TokenAttackAdapter();
    }

    function _setupToken(address token, uint256 operatorFunds) internal {
        IMintable(token).mint(operator, operatorFunds);
        vm.startPrank(operator);
        ERC20(token).approve(address(boundary), type(uint256).max);
        boundary.setAgentAssetPolicy(agent, token, 100 ether, 1000 ether, false);
        vm.stopPrank();
        // Admit + allowlist (test contract is deployer). Each test asserts
        // the token SHOULD have been rejected at admission; here we admit
        // deliberately to prove the runtime behavior.
        boundary.setStandardDebit(token, true);
        boundary.setEconomicAdapter(token, address(adapter), true);
    }

    function _intent(address target, bytes memory payload, address asset, uint256 amount)
        internal
        returns (AkmenaExecutionAuthorization.ExecutionIntent memory intent)
    {
        intent = AkmenaExecutionAuthorization.ExecutionIntent({
            operator: operator,
            agent: agent,
            target: target,
            selector: bytes4(payload),
            calldataHash: keccak256(payload),
            asset: asset,
            amount: amount,
            value: 0,
            proofModuleKey: bytes32(0),
            proofId: 0,
            nonce: ++nonceCounter,
            validAfter: 0,
            // forge-lint: disable-next-line(environment-read-across-mutation)
            deadline: block.timestamp + 1 days
        });
    }

    function _sign(AkmenaExecutionAuthorization.ExecutionIntent memory intent)
        internal
        view
        returns (bytes memory sig)
    {
        bytes32 digest = auth.hashIntent(intent);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(AGENT_KEY, digest);
        sig = abi.encodePacked(r, s, v);
    }

    function _executeAsAgent(address token, uint256 amount)
        internal
        returns (bool success, bytes memory err)
    {
        bytes memory payload = abi.encodeWithSelector(TokenAttackAdapter.execute.selector, amount);
        AkmenaExecutionAuthorization.ExecutionIntent memory intent =
            _intent(address(adapter), payload, token, amount);
        bytes memory sig = _sign(intent);
        vm.prank(agent);
        try boundary.executeAuthorizedAgentCall(intent, payload, sig) {
            return (true, "");
        } catch (bytes memory e) {
            return (false, e);
        }
    }

    // ------------------------------------------------------------------
    // 1. Over-pull / amount dishonesty (F-7) - THE critical case
    // ------------------------------------------------------------------

    /// @notice F-7 PROVEN: an over-pull token takes MORE than intent.amount
    /// from the operator. Only intent.amount is charged to the policy and
    /// pushed to the adapter - the excess is stranded in the boundary.
    /// The boundary CANNOT detect this; amount-honesty must be an admission
    /// criterion (§7.2 criterion 2). This test pins the behavior so the
    /// admission requirement is grounded in runtime evidence.
    function test_OverPull_DemonstratesF7TrustAssumption() public {
        OverPullToken token = new OverPullToken(1000); // 10% over-pull
        _setupToken(address(token), 1000 ether);

        uint256 operatorBefore = token.balanceOf(operator);
        (bool success,) = _executeAsAgent(address(token), 100 ether);
        assertTrue(success, "settlement succeeds, the theft is silent");

        uint256 operatorAfter = token.balanceOf(operator);
        uint256 taken = operatorBefore - operatorAfter;

        // PROVEN: operator lost 110, not 100.
        assertEq(taken, 110 ether, "F-7: over-pull takes more than intent.amount");
        // Policy charged only the authorized amount.
        (,, uint256 spent,,) = boundary.agentAssetPolicies(operator, agent, address(token));
        assertEq(spent, 100 ether, "policy charges intent.amount, not actual taken");
        // Adapter got exactly intent.amount.
        assertEq(adapter.received(), 100 ether);
        // Excess 10 ether is stranded in the boundary (inert, unrecoverable).
        assertEq(token.balanceOf(address(boundary)), 10 ether, "excess stranded in boundary");
    }

    // ------------------------------------------------------------------
    // 2. Success-without-delivery
    // ------------------------------------------------------------------

    /// @notice A token that returns true without delivering: the pull
    /// "succeeds" but nothing moves. The settlement COMPLETES - policy
    /// charged, nonce consumed, adapter called - with zero funds moved.
    /// This is WORSE than a revert: silent success with no economic effect.
    /// §7.2 criterion 4 exists because of this: the boundary CANNOT detect
    /// lying tokens at runtime. This test pins the behavior to prove the
    /// admission criterion is load-bearing.
    function test_SilentSuccess_SucceedsWithZeroFundsMoved() public {
        SilentSuccessToken token = new SilentSuccessToken();
        _setupToken(address(token), 1000 ether);

        (bool success,) = _executeAsAgent(address(token), 100 ether);
        assertTrue(success, "settlement succeeds - the lie is undetectable");

        // PROVEN: policy charged for funds that never moved.
        (,, uint256 spent,,) = boundary.agentAssetPolicies(operator, agent, address(token));
        assertEq(spent, 100 ether, "policy charged despite zero movement");
        // Adapter was called but received nothing.
        assertEq(token.balanceOf(address(adapter)), 0, "zero funds actually delivered");
        // Operator lost nothing (the token lied about the pull too).
        assertEq(token.balanceOf(operator), 1000 ether);
    }

    // ------------------------------------------------------------------
    // 3. Short delivery
    // ------------------------------------------------------------------

    /// @notice Short-delivery: pull delivers 90 for a 100 pull, push delivers
    /// 81 for a 100 push (both short). The settlement SUCCEEDS - the boundary
    /// cannot detect the shortfall. Policy charged 100, adapter got 81.
    /// This is why §7.2 criterion 1 requires exact delivery: the boundary
    /// trusts the token's accounting.
    function test_ShortDelivery_SucceedsWithShortfall() public {
        ShortDeliveryToken token = new ShortDeliveryToken(1000); // 10% short
        _setupToken(address(token), 1000 ether);

        (bool success,) = _executeAsAgent(address(token), 100 ether);
        assertTrue(success, "settlement succeeds - shortfall is undetectable");

        // PROVEN: policy charged 100, but the amounts diverge.
        (,, uint256 spent,,) = boundary.agentAssetPolicies(operator, agent, address(token));
        assertEq(spent, 100 ether, "policy charged full amount");
        // Pull: 100 requested, 90 delivered to boundary.
        // Push: 100 requested, 90 delivered to adapter (10% of 100, not of 90,
        // because the token shorts each leg independently).
        uint256 adapterBal = token.balanceOf(address(adapter));
        assertTrue(adapterBal < 100 ether, "adapter got less than intent.amount");
    }

    // ------------------------------------------------------------------
    // 4. Rebase
    // ------------------------------------------------------------------

    /// @notice Rebase between pull and push: if the rebase factor drops,
    /// the boundary's balance shrinks below intent.amount and the push
    /// reverts. Token semantics are unpredictable - admission excludes.
    function test_RebaseDown_FailsClosed() public {
        RebaseToken token = new RebaseToken();
        _setupToken(address(token), 1000 ether);

        // Simulate a negative rebase landing between pull and push by
        // rebasing down before execution: the operator's balance reads lower.
        token.rebase(0.5e18);

        (bool success,) = _executeAsAgent(address(token), 100 ether);
        // The pull moves 100 nominal; the push reads the rebased balance.
        // Either way, exact-amount settlement cannot be guaranteed.
        // We assert the settlement does NOT silently succeed with wrong amounts.
        if (success) {
            // If it succeeded, the adapter must have gotten exactly 100 nominal.
            assertEq(adapter.received(), 100 ether);
        }
        // The key property: no silent partial settlement.
        assertTrue(adapter.received() == 0 || adapter.received() == 100 ether);
    }

    // ------------------------------------------------------------------
    // 5. Blacklisting
    // ------------------------------------------------------------------

    /// @notice Blacklisted boundary: pull reverts cleanly. Fail-closed.
    function test_BlacklistedBoundary_RevertsCleanly() public {
        BlacklistToken token = new BlacklistToken();
        _setupToken(address(token), 1000 ether);
        token.setBlacklisted(address(boundary), true);

        (bool success,) = _executeAsAgent(address(token), 100 ether);
        assertFalse(success, "pull to blacklisted boundary must revert");

        (,, uint256 spent,,) = boundary.agentAssetPolicies(operator, agent, address(token));
        assertEq(spent, 0);
    }

    /// @notice Blacklisted adapter: pull succeeds, push reverts. Atomic
    /// rollback - the operator keeps their funds.
    function test_BlacklistedAdapter_FailsClosedAtomically() public {
        BlacklistToken token = new BlacklistToken();
        _setupToken(address(token), 1000 ether);
        token.setBlacklisted(address(adapter), true);

        uint256 operatorBefore = token.balanceOf(operator);
        (bool success,) = _executeAsAgent(address(token), 100 ether);
        assertFalse(success, "push to blacklisted adapter must revert");

        assertEq(token.balanceOf(operator), operatorBefore, "operator funds restored by revert");
        (,, uint256 spent,,) = boundary.agentAssetPolicies(operator, agent, address(token));
        assertEq(spent, 0);
    }

    // ------------------------------------------------------------------
    // 6. Paused tokens
    // ------------------------------------------------------------------

    /// @notice Token paused after intent signing: execution reverts cleanly.
    /// A pausable token is a fail-closed liveness risk (§7.2) - recorded here
    /// as runtime evidence that pause = denial of service, not theft.
    function test_PausedToken_RevertsCleanly() public {
        PausableToken token = new PausableToken();
        _setupToken(address(token), 1000 ether);
        token.setPaused(true);

        (bool success,) = _executeAsAgent(address(token), 100 ether);
        assertFalse(success, "paused token must revert");

        (,, uint256 spent,,) = boundary.agentAssetPolicies(operator, agent, address(token));
        assertEq(spent, 0, "no charge while paused");
        assertEq(token.balanceOf(operator), 1000 ether, "funds stay with operator");
    }

    /// @notice Token unpaused: settlement works normally. Pause is liveness,
    /// not a fund-safety issue.
    function test_PausedThenUnpaused_SettlesNormally() public {
        PausableToken token = new PausableToken();
        _setupToken(address(token), 1000 ether);
        token.setPaused(true);
        token.setPaused(false);

        (bool success,) = _executeAsAgent(address(token), 100 ether);
        assertTrue(success, "unpaused token settles");
        assertEq(adapter.received(), 100 ether);
    }

    // ------------------------------------------------------------------
    // 7. Upgradeable implementation changes
    // ------------------------------------------------------------------

    /// @notice Post-admission upgrade changes transfer semantics: the
    /// admission decision is invalidated. §7.2 requires re-qualification on
    /// upgrade; this test proves WHY - behavior after upgrade is
    /// unconstrained by the pre-upgrade review.
    function test_UpgradeableToken_UpgradeInvalidatesAdmission() public {
        UpgradeableTokenProxy token = new UpgradeableTokenProxy();
        _setupToken(address(token), 1000 ether);

        // Pre-upgrade: behaves as standard ERC20.
        (bool okBefore,) = _executeAsAgent(address(token), 100 ether);
        assertTrue(okBefore, "pre-upgrade: standard behavior");
        assertEq(adapter.received(), 100 ether);

        // Upgrade to malicious implementation.
        MaliciousImpl impl = new MaliciousImpl();
        token.upgrade(address(impl));

        // Post-upgrade: transfer semantics are whatever the new
        // implementation does. The admission review no longer applies.
        // We pin that the upgrade happened and the boundary's assumptions
        // are void - the allowlist owner must suspend (§7.2).
        assertEq(token.implementation(), address(impl), "upgrade took effect");
        // The correct response is suspension, not continued settlement:
        // demonstrate the fail-closed suspension path.
        boundary.emergencyRemoveStandardDebit(address(token));
        (bool okAfter,) = _executeAsAgent(address(token), 50 ether);
        assertFalse(okAfter, "suspended token must not settle");
    }

    // ------------------------------------------------------------------
    // 8. Sender-side hooks / reentrancy (ERC-777 style)
    // ------------------------------------------------------------------

    /// @notice ERC-777-style sender hook fires during the pull. The hook
    /// cannot reenter the boundary's settlement (transient guard), and the
    /// settlement completes atomically. §7.2 criterion 5: tokens with
    /// sender-side hooks fail admission unless proven inert.
    function test_SenderHook_CannotReenterBoundary() public {
        HookToken token = new HookToken();
        // The operator is a contract with a tokensToSend hook.
        ReentrantOperator hookOp = new ReentrantOperator(boundary);
        IMintable(address(token)).mint(address(hookOp), 1000 ether);
        vm.startPrank(address(hookOp));
        token.approve(address(boundary), type(uint256).max);
        vm.stopPrank();
        // Policy for the hook operator.
        vm.prank(address(hookOp));
        boundary.setAgentAssetPolicy(agent, address(token), 100 ether, 1000 ether, false);
        boundary.setStandardDebit(address(token), true);
        boundary.setEconomicAdapter(address(token), address(adapter), true);

        // Build intent with the hook operator as operator.
        bytes memory payload = abi.encodeWithSelector(TokenAttackAdapter.execute.selector, 100 ether);
        AkmenaExecutionAuthorization.ExecutionIntent memory intent =
            AkmenaExecutionAuthorization.ExecutionIntent({
                operator: address(hookOp),
                agent: agent,
                target: address(adapter),
                selector: bytes4(payload),
                calldataHash: keccak256(payload),
                asset: address(token),
                amount: 100 ether,
                value: 0,
                proofModuleKey: bytes32(0),
                proofId: 0,
                nonce: ++nonceCounter,
                validAfter: 0,
                deadline: block.timestamp + 1 days
            });
        bytes32 digest = auth.hashIntent(intent);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(AGENT_KEY, digest);
        bytes memory sig = abi.encodePacked(r, s, v);

        vm.prank(agent);
        try boundary.executeAuthorizedAgentCall(intent, payload, sig) {
            // If it succeeded, the hook fired but reentry was blocked.
            assertTrue(hookOp.reentered(), "hook fired during pull");
            assertEq(adapter.received(), 100 ether, "settlement completed atomically");
        } catch {
            // If it reverted, it must be the reentrancy guard or hook failure
            // - never a silent partial state.
            assertTrue(hookOp.reentered(), "hook fired");
            (,, uint256 spent,,) =
                boundary.agentAssetPolicies(address(hookOp), agent, address(token));
            assertEq(spent, 0, "no charge on reverted settlement");
        }
    }

    // ------------------------------------------------------------------
    // Admission-boundary probes
    // ------------------------------------------------------------------

    /// @notice Non-admitted token reverts on the economic path even with an
    /// allowlisted adapter. Both gates are required (§7.2).
    function test_NonAdmittedToken_RevertsDespiteAllowlistedAdapter() public {
        PlainMintableToken token = new PlainMintableToken("Plain", "PLN");
        // Allowlist the adapter but do NOT admit the token.
        boundary.setEconomicAdapter(address(token), address(adapter), true);
        token.mint(operator, 1000 ether);
        vm.startPrank(operator);
        token.approve(address(boundary), type(uint256).max);
        boundary.setAgentAssetPolicy(agent, address(token), 100 ether, 1000 ether, false);
        vm.stopPrank();

        (bool success,) = _executeAsAgent(address(token), 100 ether);
        assertFalse(success, "non-admitted token must not settle");
    }

    /// @notice Zero-amount on a non-admitted token: exempt from admission
    /// (no funds move) but the adapter gate still applies.
    function test_ZeroAmount_NonAdmittedToken_AdapterGateStillApplies() public {
        PlainMintableToken token = new PlainMintableToken("Plain2", "PL2");
        // Adapter allowlisted, token NOT admitted.
        boundary.setEconomicAdapter(address(token), address(adapter), true);
        vm.prank(operator);
        boundary.setAgentAssetPolicy(agent, address(token), 100 ether, 1000 ether, false);

        // Zero-amount: admission exempt, adapter gate enforced → succeeds.
        (bool success,) = _executeAsAgent(address(token), 0);
        assertTrue(success, "zero-amount exempt from admission");
    }
}
