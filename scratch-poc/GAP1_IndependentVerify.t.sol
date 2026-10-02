// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaCore} from "../src/core/AkmenaCore.sol";
import {AkmenaPolicyBoundary} from "../src/authorization/AkmenaPolicyBoundary.sol";
import {AkmenaExecutionAuthorization} from "../src/authorization/AkmenaExecutionAuthorization.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract GAP1VerifyRecorder {
    uint256 public callCount;
    function record() external payable { callCount++; }
}

contract GAP1VerifyToken is ERC20 {
    constructor() ERC20("GAP1V", "G1V") {}
    function mint(address to, uint256 amt) external { _mint(to, amt); }
}

contract GAP1VerifyAdapter {
    uint256 public received;
    function execute(uint256 amount) external returns (bool) {
        received += amount;
        return true;
    }
}

/// @notice Independent verification of GAP-1 hardening (2026-10-01).
/// All assertions are hard (assertEq / expectRevert), not log-only.
contract GAP1IndependentVerifyTest is Test {
    uint256 internal constant AGENT_KEY = 0x6A9;
    address internal agent;
    address internal operator = address(0xB0B);

    AkmenaCore internal core;
    AkmenaPolicyBoundary internal boundary;
    AkmenaExecutionAuthorization internal auth;
    GAP1VerifyRecorder internal recorder;
    GAP1VerifyToken internal token;
    GAP1VerifyAdapter internal adapter;

    function setUp() public {
        agent = vm.addr(AGENT_KEY);
        core = new AkmenaCore();
        boundary = new AkmenaPolicyBoundary(address(core));
        auth = AkmenaExecutionAuthorization(address(boundary.executionAuthorization()));
        recorder = new GAP1VerifyRecorder();
        token = new GAP1VerifyToken();
        adapter = new GAP1VerifyAdapter();

        // Native policy: 100/tx, 1000/day
        vm.prank(operator);
        boundary.setAgentPolicy(agent, 100 ether, 1000 ether, false);

        // ERC20 policy + admission
        boundary.setEconomicAdapter(address(token), address(adapter), true);
        boundary.setStandardDebit(address(token), true);
        token.mint(operator, 1_000_000 ether);
        vm.startPrank(operator);
        boundary.setAgentAssetPolicy(agent, address(token), 100 ether, 1000 ether, false);
        token.approve(address(boundary), 10_000 ether);
        vm.stopPrank();
    }

    function _nativeIntent(address target, bytes memory payload, uint256 amount, uint256 value, uint256 nonce)
        internal view returns (AkmenaExecutionAuthorization.ExecutionIntent memory)
    {
        return AkmenaExecutionAuthorization.ExecutionIntent({
            operator: operator,
            agent: agent,
            target: target,
            selector: bytes4(payload),
            asset: address(0),
            calldataHash: keccak256(payload),
            amount: amount,
            value: value,
            proofModuleKey: bytes32(0),
            proofId: 0,
            nonce: nonce,
            validAfter: block.timestamp,
            deadline: block.timestamp + 1 hours
        });
    }

    function _erc20Intent(address target, bytes memory payload, uint256 amount, uint256 nonce)
        internal view returns (AkmenaExecutionAuthorization.ExecutionIntent memory)
    {
        return AkmenaExecutionAuthorization.ExecutionIntent({
            operator: operator,
            agent: agent,
            target: target,
            selector: bytes4(payload),
            asset: address(token),
            calldataHash: keccak256(payload),
            amount: amount,
            value: 0,
            proofModuleKey: bytes32(0),
            proofId: 0,
            nonce: nonce,
            validAfter: block.timestamp,
            deadline: block.timestamp + 1 hours
        });
    }

    function _sign(AkmenaExecutionAuthorization.ExecutionIntent memory intent) internal view returns (bytes memory) {
        bytes32 digest = auth.hashIntent(intent);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(AGENT_KEY, digest);
        return abi.encodePacked(r, s, v);
    }

    function _spentNative() internal view returns (uint256) {
        (,, uint256 spent,,) = boundary.agentPolicies(operator, agent);
        return spent;
    }

    function _spentToken() internal view returns (uint256) {
        (,, uint256 spent,,) = boundary.agentAssetPolicies(operator, agent, address(token));
        return spent;
    }

    /// @notice The exact GAP-1 DoS scenario: 10 zero-value native intents
    /// declaring 100 ether each must NOT consume the daily limit.
    function test_GAP1_ZeroValueNativeSpamDoesNotChargeLimit() public {
        for (uint256 i = 0; i < 10; i++) {
            bytes memory payload = abi.encodeWithSelector(GAP1VerifyRecorder.record.selector);
            AkmenaExecutionAuthorization.ExecutionIntent memory intent =
                _nativeIntent(address(recorder), payload, 100 ether, 0, i);
            bytes memory sig = _sign(intent);
            vm.prank(agent);
            boundary.executeAuthorizedAgentCall(intent, payload, sig);
        }
        assertEq(recorder.callCount(), 10, "all 10 zero-value calls executed");
        assertEq(_spentNative(), 0, "GAP-1: zero-value native must not charge daily limit");
    }

    /// @notice Native intents WITH value still charge the daily limit exactly.
    function test_GAP1_NativeWithValueStillCharged() public {
        vm.deal(agent, 200 ether);
        bytes memory payload = abi.encodeWithSelector(GAP1VerifyRecorder.record.selector);
        AkmenaExecutionAuthorization.ExecutionIntent memory intent =
            _nativeIntent(address(recorder), payload, 50 ether, 50 ether, 0);
        bytes memory sig = _sign(intent);
        vm.prank(agent);
        boundary.executeAuthorizedAgentCall{value: 50 ether}(intent, payload, sig);
        assertEq(recorder.callCount(), 1, "call executed");
        assertEq(_spentNative(), 50 ether, "value-carrying native must charge exactly msg.value");
    }

    /// @notice A native settlement exceeding remaining daily headroom reverts.
    function test_GAP1_NativeOverLimitReverts() public {
        // Widen per-tx so the daily limit (not per-tx) is the binding constraint.
        vm.prank(operator);
        boundary.setAgentPolicy(agent, 1000 ether, 1000 ether, false);
        vm.deal(agent, 2000 ether);
        bytes memory payload = abi.encodeWithSelector(GAP1VerifyRecorder.record.selector);
        // Pre-fill 900 of 1000 daily.
        for (uint256 i = 0; i < 9; i++) {
            AkmenaExecutionAuthorization.ExecutionIntent memory it =
                _nativeIntent(address(recorder), payload, 100 ether, 100 ether, i);
            bytes memory itsig = _sign(it);
            vm.prank(agent);
            boundary.executeAuthorizedAgentCall{value: 100 ether}(it, payload, itsig);
        }
        assertEq(_spentNative(), 900 ether, "pre-fill 900");
        // 200 more exceeds remaining headroom (100) -> PolicyExceeded.
        AkmenaExecutionAuthorization.ExecutionIntent memory over =
            _nativeIntent(address(recorder), payload, 200 ether, 200 ether, 100);
        bytes memory oversig = _sign(over);
        vm.prank(agent);
        vm.expectRevert(AkmenaPolicyBoundary.PolicyExceeded.selector);
        boundary.executeAuthorizedAgentCall{value: 200 ether}(over, payload, oversig);
        // spent unchanged after revert
        assertEq(_spentNative(), 900 ether, "reverted settlement must not charge");
        // Exactly filling the limit (100) succeeds.
        AkmenaExecutionAuthorization.ExecutionIntent memory exact =
            _nativeIntent(address(recorder), payload, 100 ether, 100 ether, 101);
        bytes memory exsig = _sign(exact);
        vm.prank(agent);
        boundary.executeAuthorizedAgentCall{value: 100 ether}(exact, payload, exsig);
        assertEq(_spentNative(), 1000 ether, "exact fill charges to limit");
    }

    /// @notice intent.amount > 0 with msg.value == 0 (the old DoS shape) now succeeds free.
    function test_GAP1_DeclaredAmountWithoutValueNotCharged() public {
        bytes memory payload = abi.encodeWithSelector(GAP1VerifyRecorder.record.selector);
        AkmenaExecutionAuthorization.ExecutionIntent memory intent =
            _nativeIntent(address(recorder), payload, 100 ether, 0, 0);
        bytes memory sig = _sign(intent);
        vm.prank(agent);
        boundary.executeAuthorizedAgentCall(intent, payload, sig);
        assertEq(_spentNative(), 0, "declared amount with zero value must not charge");
    }

    /// @notice Native value/amount mismatch still reverts (accounting integrity).
    function test_GAP1_NativeValueMismatchReverts() public {
        vm.deal(agent, 200 ether);
        bytes memory payload = abi.encodeWithSelector(GAP1VerifyRecorder.record.selector);
        // intent.value=50 but msg.value=60
        AkmenaExecutionAuthorization.ExecutionIntent memory intent =
            _nativeIntent(address(recorder), payload, 50 ether, 50 ether, 0);
        bytes memory sig = _sign(intent);
        vm.prank(agent);
        vm.expectRevert(AkmenaPolicyBoundary.NativeValueMismatch.selector);
        boundary.executeAuthorizedAgentCall{value: 60 ether}(intent, payload, sig);
    }

    /// @notice Zero-amount ERC20 intents do not charge; with-amount intents do.
    function test_GAP1_ERC20ZeroAmountNoCharge() public {
        bytes memory payload = abi.encodeWithSelector(GAP1VerifyAdapter.execute.selector, 0);
        AkmenaExecutionAuthorization.ExecutionIntent memory intent =
            _erc20Intent(address(adapter), payload, 0, 0);
        bytes memory sig = _sign(intent);
        vm.prank(agent);
        boundary.executeAuthorizedAgentCall(intent, payload, sig);
        assertEq(_spentToken(), 0, "zero-amount ERC20 must not charge daily limit");
    }

    function test_GAP1_ERC20WithAmountStillCharged() public {
        bytes memory payload = abi.encodeWithSelector(GAP1VerifyAdapter.execute.selector, 50 ether);
        AkmenaExecutionAuthorization.ExecutionIntent memory intent =
            _erc20Intent(address(adapter), payload, 50 ether, 0);
        bytes memory sig = _sign(intent);
        vm.prank(agent);
        boundary.executeAuthorizedAgentCall(intent, payload, sig);
        assertEq(adapter.received(), 50 ether, "adapter received exact amount");
        assertEq(_spentToken(), 50 ether, "ERC20 settlement must charge exactly intent.amount");
    }
}
