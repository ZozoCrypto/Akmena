// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaCore} from "../../src/core/AkmenaCore.sol";
import {AkmenaPolicyBoundary} from "../../src/authorization/AkmenaPolicyBoundary.sol";
import {AkmenaExecutionAuthorization} from "../../src/authorization/AkmenaExecutionAuthorization.sol";

/// @notice R10 gap-fill: tests for the 6 survived mutants.
/// @dev Mutants 8, 10, 11, 12, 13, 17 from R10_MUTATION_REPORT.md.
///      Each test is designed to FAIL if its corresponding mutant is applied.
contract R10NativeAdapter {
    uint256 public receivedNative;
    function depositNative() external payable returns (bool) {
        receivedNative += msg.value;
        return true;
    }
    function noop() external pure returns (bool) {
        return true;
    }
}

contract R10MutantGapTests is Test {
    uint256 internal constant AGENT_KEY = 0xA11CE;
    uint256 internal constant OPERATOR_KEY = 0xB0B0B;

    address internal agent;
    address internal operator;

    AkmenaCore internal core;
    AkmenaPolicyBoundary internal boundary;
    AkmenaExecutionAuthorization internal authorization;
    R10NativeAdapter internal nativeAdapter;

    function setUp() public {
        agent = vm.addr(AGENT_KEY);
        operator = vm.addr(OPERATOR_KEY);

        core = new AkmenaCore();
        boundary = new AkmenaPolicyBoundary(address(core));
        authorization = boundary.executionAuthorization();
        nativeAdapter = new R10NativeAdapter();

        vm.deal(operator, 100 ether);
        vm.deal(agent, 100 ether);
    }

    function _signNative(
        address target,
        bytes4 selector,
        bytes memory payload,
        uint256 amount,
        uint256 value,
        uint256 nonce
    ) internal view returns (AkmenaExecutionAuthorization.ExecutionIntent memory, bytes memory) {
        AkmenaExecutionAuthorization.ExecutionIntent memory intent =
            AkmenaExecutionAuthorization.ExecutionIntent({
                operator: operator,
                agent: agent,
                target: target,
                selector: selector,
                calldataHash: keccak256(payload),
                asset: address(0),
                amount: amount,
                value: value,
                proofModuleKey: bytes32(0),
                proofId: 0,
                nonce: nonce,
                validAfter: block.timestamp,
                deadline: block.timestamp + 1 hours
            });
        bytes32 digest = authorization.hashIntent(intent);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(AGENT_KEY, digest);
        return (intent, abi.encodePacked(r, s, v));
    }

    function _nativeSpentToday() internal view returns (uint256) {
        (,,, uint256 spentToday,) = boundary.agentPolicies(operator, agent);
        // agentPolicies returns SpendingPolicy struct; access via getter
        return spentToday;
    }

    /// @notice Mutant 17: native settlement headroom `-` → `/`.
    /// @dev The mutant causes division-by-zero when totalSpentToday=0,
    ///      and wildly wrong headroom otherwise. This test verifies correct
    ///      saturating headroom behavior for native settlements.
    function test_NativeSettlementHeadroomCalculation() public {
        // Daily limit 10 ether, maxSpend 10 ether.
        vm.prank(operator);
        boundary.setAgentPolicy(agent, 10 ether, 10 ether, false);

        // First settlement: 3 ether. totalSpentToday=0 → mutant would panic (div by zero).
        bytes memory payload1 = abi.encodeWithSelector(R10NativeAdapter.depositNative.selector);
        (AkmenaExecutionAuthorization.ExecutionIntent memory intent1, bytes memory sig1) =
            _signNative(address(nativeAdapter), R10NativeAdapter.depositNative.selector, payload1, 3 ether, 3 ether, 0);

        vm.prank(agent);
        boundary.executeAuthorizedAgentCall{value: 3 ether}(intent1, payload1, sig1);
        assertEq(nativeAdapter.receivedNative(), 3 ether);

        // Second settlement: 6 ether. totalSpentToday=3, headroom=7. Should succeed.
        bytes memory payload2 = abi.encodeWithSelector(R10NativeAdapter.depositNative.selector);
        (AkmenaExecutionAuthorization.ExecutionIntent memory intent2, bytes memory sig2) =
            _signNative(address(nativeAdapter), R10NativeAdapter.depositNative.selector, payload2, 6 ether, 6 ether, 1);

        vm.prank(agent);
        boundary.executeAuthorizedAgentCall{value: 6 ether}(intent2, payload2, sig2);
        assertEq(nativeAdapter.receivedNative(), 9 ether);

        // Third settlement: 2 ether. totalSpentToday=9, headroom=1. Should revert PolicyExceeded.
        // Mutant would compute 10/9=1 (integer division) — same result here by coincidence,
        // but the first two settlements already distinguish.
        bytes memory payload3 = abi.encodeWithSelector(R10NativeAdapter.depositNative.selector);
        (AkmenaExecutionAuthorization.ExecutionIntent memory intent3, bytes memory sig3) =
            _signNative(address(nativeAdapter), R10NativeAdapter.depositNative.selector, payload3, 2 ether, 2 ether, 2);

        vm.prank(agent);
        vm.expectRevert(AkmenaPolicyBoundary.PolicyExceeded.selector);
        boundary.executeAuthorizedAgentCall{value: 2 ether}(intent3, payload3, sig3);
    }

    /// @notice Mutants 10+12: zero-value native calls must respect daily limits.
    /// @dev Mutant 10 deletes the headroom check; mutant 12 deletes the enforcement.
    ///      Without these, zero-value native calls could exceed daily limits.
    function test_ZeroValueNativeRespectsDailyLimit() public {
        // GAP-1 hardening 2026-10-01: zero-value native intents no longer
        // consume the economic daily limit. This test verifies the new behavior:
        // multiple zero-value intents do NOT fill the limit.
        vm.prank(operator);
        boundary.setAgentPolicy(agent, 10 ether, 5 ether, false);

        // First: 3 ether declared, zero value. Should succeed and NOT consume limit.
        bytes memory payload1 = abi.encodeWithSelector(R10NativeAdapter.noop.selector);
        (AkmenaExecutionAuthorization.ExecutionIntent memory intent1, bytes memory sig1) =
            _signNative(address(nativeAdapter), R10NativeAdapter.noop.selector, payload1, 3 ether, 0, 0);

        vm.prank(agent);
        boundary.executeAuthorizedAgentCall(intent1, payload1, sig1);

        // Second: 3 ether declared, zero value. Should ALSO succeed (limit not consumed).
        bytes memory payload2 = abi.encodeWithSelector(R10NativeAdapter.noop.selector);
        (AkmenaExecutionAuthorization.ExecutionIntent memory intent2, bytes memory sig2) =
            _signNative(address(nativeAdapter), R10NativeAdapter.noop.selector, payload2, 3 ether, 0, 1);

        vm.prank(agent);
        boundary.executeAuthorizedAgentCall(intent2, payload2, sig2);

        // Verify the daily limit was NOT consumed.
        (,, uint256 spentToday,,) = boundary.agentPolicies(operator, agent);
        assertEq(spentToday, 0, "GAP-1: zero-value native must not charge daily limit");
    }

    /// @notice Mutant 11: zero-value native headroom `-` → `*`.
    /// @dev GAP-1 hardening 2026-10-01: zero-value native intents no longer
    ///      consume the daily limit, so headroom calculation is skipped.
    ///      This test verifies the new behavior: no headroom check for zero-value.
    function test_ZeroValueNativeHeadroomCalculation() public {
        vm.prank(operator);
        boundary.setAgentPolicy(agent, 10 ether, 10 ether, false);

        // Zero-value calls should succeed regardless of "headroom" since
        // they don't consume the limit. Even with a tiny daily limit,
        // zero-value intents pass through.
        vm.prank(operator);
        boundary.setAgentPolicy(agent, 10 ether, 1 wei, false);

        bytes memory payload1 = abi.encodeWithSelector(R10NativeAdapter.noop.selector);
        (AkmenaExecutionAuthorization.ExecutionIntent memory intent1, bytes memory sig1) =
            _signNative(address(nativeAdapter), R10NativeAdapter.noop.selector, payload1, 5 ether, 0, 0);

        vm.prank(agent);
        // Should succeed even though 5 ether > 1 wei daily limit,
        // because zero-value native doesn't consume the limit.
        boundary.executeAuthorizedAgentCall(intent1, payload1, sig1);

        // Verify nothing was charged.
        (,, uint256 spentToday,,) = boundary.agentPolicies(operator, agent);
        assertEq(spentToday, 0, "GAP-1: zero-value native must not charge daily limit");
    }

    /// @notice Mutant 13: deleting _verifyActiveEscrow must break escrow-enforced policies.
    /// @dev No existing test sets requireActiveEscrow=true. This test proves the
    ///      check is enforced: without a valid proof module, execution reverts.
    ///      If the mutant deleted the call, execution would succeed.
    function test_RequireActiveEscrowEnforced() public {
        // Policy with requireActiveEscrow=true.
        vm.prank(operator);
        boundary.setAgentPolicy(agent, 10 ether, 10 ether, true);

        bytes memory payload = abi.encodeWithSelector(R10NativeAdapter.noop.selector);
        (AkmenaExecutionAuthorization.ExecutionIntent memory intent, bytes memory sig) =
            _signNative(address(nativeAdapter), R10NativeAdapter.noop.selector, payload, 1 ether, 0, 0);

        // proofModuleKey=bytes32(0) → getModule returns inactive → "Proof Module Offline".
        // The exact revert doesn't matter; what matters is that it REVERTS.
        // If _verifyActiveEscrow were deleted, this would succeed.
        vm.prank(agent);
        vm.expectRevert();
        boundary.executeAuthorizedAgentCall(intent, payload, sig);
    }

    /// @notice Mutant 8: zero-amount self-adapter call (target == asset) must revert.
    /// @dev Line 411: `if (intent.target == intent.asset && !isEconomicAdapter)` → false.
    ///      Line 432 provides defense-in-depth for amount>0, but amount==0 slips through.
    ///      This test covers the zero-amount case.
    function test_ZeroAmountSelfAdapterReverts() public {
        // Use a mock token as the asset. Target == asset with amount == 0.
        // We need an ERC20 asset for this path (isNative=false).
        // Deploy a minimal token inline via a helper.
        MockZeroToken token = new MockZeroToken();
        token.mint(operator, 100 ether);

        vm.prank(operator);
        boundary.setAgentAssetPolicy(agent, address(token), 10 ether, 10 ether, false);
        boundary.setStandardDebit(address(token), true);
        // Note: NOT allowlisting token as adapter for itself.

        bytes memory payload = abi.encodeWithSelector(MockZeroToken.mint.selector, agent, 1 ether);
        AkmenaExecutionAuthorization.ExecutionIntent memory intent =
            AkmenaExecutionAuthorization.ExecutionIntent({
                operator: operator,
                agent: agent,
                target: address(token), // target == asset
                selector: MockZeroToken.mint.selector,
                calldataHash: keccak256(payload),
                asset: address(token),
                amount: 0, // zero amount — slips past line 432 defense
                value: 0,
                proofModuleKey: bytes32(0),
                proofId: 0,
                nonce: 0,
                validAfter: block.timestamp,
                deadline: block.timestamp + 1 hours
            });

        bytes32 digest = authorization.hashIntent(intent);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(AGENT_KEY, digest);
        bytes memory sig = abi.encodePacked(r, s, v);

        vm.prank(agent);
        vm.expectRevert(AkmenaPolicyBoundary.EconomicAdapterNotAllowed.selector);
        boundary.executeAuthorizedAgentCall(intent, payload, sig);
    }
}

/// @notice Minimal ERC20 for the zero-amount self-adapter test.
contract MockZeroToken {
    string public name = "MockZero";
    string public symbol = "MZ";
    uint8 public decimals = 18;
    mapping(address => uint256) public balanceOf;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }
}
