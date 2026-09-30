// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/core/AkmenaCore.sol";
import "../src/authorization/AkmenaPolicyBoundary.sol";
import "../src/authorization/AkmenaExecutionAuthorization.sol";

/// Minimal mock ERC20 used to stage the attack (identical to V0_OperatorDrain).
contract MockERC20V0Closed {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amt) external {
        balanceOf[to] += amt;
    }

    function approve(address spender, uint256 amt) external returns (bool) {
        allowance[msg.sender][spender] = amt;
        return true;
    }

    function transfer(address to, uint256 amt) external returns (bool) {
        balanceOf[msg.sender] -= amt;
        balanceOf[to] += amt;
        return true;
    }

    function transferFrom(address from, address to, uint256 amt) external returns (bool) {
        uint256 al = allowance[from][msg.sender];
        require(al >= amt, "MockERC20: insufficient allowance");
        if (al != type(uint256).max) {
            allowance[from][msg.sender] = al - amt;
        }
        balanceOf[from] -= amt;
        balanceOf[to] += amt;
        return true;
    }
}

/// PoC — V-0 CLOSED BY CONSTRUCTION under Model D (feature/model-d-operator-custody).
///
/// The historical V-0 drain (see V0_OperatorDrain.t.sol, staged against
/// 00428402) is structurally impossible under operator-funded settlement:
/// the boundary pulls EXACTLY intent.amount from intent.operator BEFORE
/// pushing anything to the adapter. There is no pooled-balance tap for a
/// legacy self-adapter grant to reach.
///
/// ADDITIONAL HARDENING (found during Model D testing, 2026-09-29):
///   A legacy self-adapter grant ALONE (without the fix below) permitted
///   costless griefing of stranded pools: pull X from the attacker ->
///   push X to the token contract -> call transfer(attacker, X) draws X from
///   the boundary's commingled balance. The attacker's capital recycles
///   (net zero) while X of victim pool is destroyed into the token contract
///   per cycle — pure vandalism at gas cost. Fixed by rejecting
///   target == asset for value-moving intents at execution time
///   (InvalidAdapter), layering over the 00428402 config-time guard.
///
/// V-9 PRECONDITION (honest modeling, same as the original PoC):
///   economicAdapters[token][token] == true is simulated via vm.store —
///   a pre-00428402 legacy self-adapter grant still present in storage.
///   New grants revert InvalidAdapter; this is the ONLY non-on-chain step.
///
/// EXPECTED RESULTS (Model D, hardened):
///   test_V0_DrainAttemptRevertsWithoutApproval -> reverts InvalidAdapter; pool untouched.
///   test_V0_LegacyGrantGriefingBlocked         -> reverts InvalidAdapter; pool and attacker funds untouched.
///   test_N7_FreshDeploymentStillInert          -> reverts EconomicAdapterNotAllowed; nothing moves.
contract V0_ClosedByConstructionTest is Test {
    uint256 internal constant ATTACKER_KEY = 0xB0B;
    address internal attacker;
    address internal victim = address(0x1234);

    AkmenaCore internal core;
    AkmenaPolicyBoundary internal boundary;
    AkmenaExecutionAuthorization internal auth;
    MockERC20V0Closed internal token;

    uint256 internal nonce = 1;

    function setUp() public {
        attacker = vm.addr(ATTACKER_KEY);

        core = new AkmenaCore();
        boundary = new AkmenaPolicyBoundary(address(core));
        auth = boundary.executionAuthorization();

        token = new MockERC20V0Closed();

        // Victim funds the (legacy) boundary pool. No attribution recorded.
        token.mint(victim, 1000e18);
        vm.prank(victim);
        token.transfer(address(boundary), 1000e18);
    }

    /// economicAdapters is declared at storage slot 2 in AkmenaPolicyBoundary.
    function _allowlistSlot(address asset, address adpt) internal pure returns (bytes32) {
        bytes32 inner = keccak256(abi.encode(asset, uint256(2)));
        return keccak256(abi.encode(adpt, inner));
    }

    /// Simulate the V-9 legacy state. ONLY non-on-chain step.
    function _legacySelfAdapterGrant() internal {
        vm.store(address(boundary), _allowlistSlot(address(token), address(token)), bytes32(uint256(1)));
        assertTrue(
            boundary.economicAdapters(address(token), address(token)), "legacy grant simulation failed"
        );
    }

    function _sign(AkmenaExecutionAuthorization.ExecutionIntent memory intent, uint256 key)
        internal
        view
        returns (bytes memory)
    {
        bytes32 digest = auth.hashIntent(intent);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);
        return abi.encodePacked(r, s, v);
    }

    function _drainIntent(uint256 amount, uint256 n)
        internal
        view
        returns (AkmenaExecutionAuthorization.ExecutionIntent memory, bytes memory)
    {
        bytes memory payload = abi.encodeCall(MockERC20V0Closed.transfer, (attacker, amount));
        AkmenaExecutionAuthorization.ExecutionIntent memory intent = AkmenaExecutionAuthorization.ExecutionIntent({
            operator: attacker,
            agent: attacker,
            target: address(token),
            selector: MockERC20V0Closed.transfer.selector,
            calldataHash: keccak256(payload),
            asset: address(token),
            amount: amount,
            value: 0,
            proofModuleKey: bytes32(0),
            proofId: 0,
            nonce: n,
            validAfter: 0,
            deadline: block.timestamp + 7 days
        });
        return (intent, payload);
    }

    /// The exact historical V-0 attack, replayed under Model D: legacy grant
    /// in place, attacker self-registers a maximal policy, signs as their own
    /// agent. Target == asset is rejected at execution time (InvalidAdapter)
    /// before any funds move — the legacy grant is dead code on the
    /// value-moving path.
    function test_V0_DrainAttemptRevertsWithoutApproval() public {
        _legacySelfAdapterGrant();

        vm.prank(attacker);
        boundary.setAgentAssetPolicy(attacker, address(token), type(uint256).max, type(uint256).max, false);

        (AkmenaExecutionAuthorization.ExecutionIntent memory intent, bytes memory payload) =
            _drainIntent(1000e18, nonce++);
        bytes memory sig = _sign(intent, ATTACKER_KEY);

        vm.prank(attacker);
        vm.expectRevert(AkmenaPolicyBoundary.InvalidAdapter.selector);
        boundary.executeAuthorizedAgentCall(intent, payload, sig);

        // The victim pool is untouched; the attacker gained nothing.
        assertEq(token.balanceOf(address(boundary)), 1000e18, "victim pool moved");
        assertEq(token.balanceOf(attacker), 0, "attacker received tokens");

        (,, uint256 totalSpentToday,,) = boundary.agentAssetPolicies(attacker, attacker, address(token));
        assertEq(totalSpentToday, 0, "spend recorded for a reverted execution");
    }

    /// The griefing variant is blocked at the same gate: even with the
    /// attacker fully cooperating (own funding + approval), a value-moving
    /// intent targeting the asset itself reverts. The stranded pool cannot
    /// be drawn down 1:1 into the token contract.
    function test_V0_LegacyGrantGriefingBlocked() public {
        _legacySelfAdapterGrant();

        token.mint(attacker, 1000e18);
        vm.prank(attacker);
        token.approve(address(boundary), type(uint256).max);

        vm.prank(attacker);
        boundary.setAgentAssetPolicy(attacker, address(token), type(uint256).max, type(uint256).max, false);

        (AkmenaExecutionAuthorization.ExecutionIntent memory intent, bytes memory payload) =
            _drainIntent(1000e18, nonce++);
        bytes memory sig = _sign(intent, ATTACKER_KEY);

        vm.prank(attacker);
        vm.expectRevert(AkmenaPolicyBoundary.InvalidAdapter.selector);
        boundary.executeAuthorizedAgentCall(intent, payload, sig);

        // Nothing moved: pool intact, attacker's own funds untouched.
        assertEq(token.balanceOf(address(boundary)), 1000e18, "victim pool moved");
        assertEq(token.balanceOf(attacker), 1000e18, "attacker own funds moved");
        assertEq(token.balanceOf(address(token)), 0, "token contract received funds");

        (,, uint256 totalSpentToday,,) = boundary.agentAssetPolicies(attacker, attacker, address(token));
        assertEq(totalSpentToday, 0, "spend recorded for a reverted execution");
    }

    /// N-7 control, preserved: on a fresh deployment (no legacy grant) the
    /// identical attack reverts at the allowlist gate and nothing moves.
    function test_N7_FreshDeploymentStillInert() public {
        vm.prank(attacker);
        boundary.setAgentAssetPolicy(attacker, address(token), type(uint256).max, type(uint256).max, false);

        (AkmenaExecutionAuthorization.ExecutionIntent memory intent, bytes memory payload) =
            _drainIntent(1000e18, nonce++);
        bytes memory sig = _sign(intent, ATTACKER_KEY);

        vm.prank(attacker);
        vm.expectRevert(AkmenaPolicyBoundary.EconomicAdapterNotAllowed.selector);
        boundary.executeAuthorizedAgentCall(intent, payload, sig);

        assertEq(token.balanceOf(address(boundary)), 1000e18, "boundary balance changed on fresh deployment");
        assertEq(token.balanceOf(attacker), 0, "attacker received tokens on fresh deployment");
    }
}
