// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaCore} from "../../src/core/AkmenaCore.sol";
import {AkmenaPolicyBoundary} from "../../src/authorization/AkmenaPolicyBoundary.sol";
import {AkmenaExecutionAuthorization} from "../../src/authorization/AkmenaExecutionAuthorization.sol";

contract NativeGapRecorder {
    uint256 public callCount;
    function record() external payable { callCount++; }
}

/// @notice GAP-1 (native) and GAP-2 focused tests.
/// GAP-1: Native zero-value intents charge policy.intent.amount without moving funds.
/// GAP-2: Native intents bypass adapter allowlist (once policy exists).
contract NativeGapTest is Test {
    uint256 internal constant AGENT_KEY = 0x6A9;
    address internal agent;
    address internal operator = address(0xB0B);

    AkmenaCore internal core;
    AkmenaPolicyBoundary internal boundary;
    AkmenaExecutionAuthorization internal auth;
    NativeGapRecorder internal recorder;

    function setUp() public {
        agent = vm.addr(AGENT_KEY);
        core = new AkmenaCore();
        boundary = new AkmenaPolicyBoundary(address(core));
        auth = AkmenaExecutionAuthorization(address(boundary.executionAuthorization()));
        recorder = new NativeGapRecorder();

        // Operator sets policy for NATIVE via setAgentPolicy (not setAgentAssetPolicy)
        vm.prank(operator);
        boundary.setAgentPolicy(agent, 100 ether, 1000 ether, false);
    }

    function _nativeIntent(
        address target,
        bytes memory payload,
        bytes4 selector,
        uint256 amount,
        uint256 value,
        uint256 nonce
    ) internal view returns (AkmenaExecutionAuthorization.ExecutionIntent memory) {
        return AkmenaExecutionAuthorization.ExecutionIntent({
            operator: operator,
            agent: agent,
            target: target,
            selector: selector,
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

    function _sign(AkmenaExecutionAuthorization.ExecutionIntent memory intent)
        internal view returns (bytes memory)
    {
        bytes32 digest = auth.hashIntent(intent);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(AGENT_KEY, digest);
        return abi.encodePacked(r, s, v);
    }

    function _spentToday() internal view returns (uint256) {
        (, , uint256 spent,,) = boundary.agentPolicies(operator, agent);
        return spent;
    }

    /// @notice GAP-1 NATIVE: Zero-value native intents charge intent.amount to policy.
    function test_GAP1_NativeZeroValueFillsDailyLimit() public {
        // Spam 10 native zero-value intents with amount=100 ether each.
        // msg.value == 0, so no ETH moves, but policy is charged intent.amount.
        for (uint256 i = 0; i < 10; i++) {
            bytes memory payload = abi.encodeWithSelector(NativeGapRecorder.record.selector);
            AkmenaExecutionAuthorization.ExecutionIntent memory intent = _nativeIntent(
                address(recorder), payload, NativeGapRecorder.record.selector, 100 ether, 0, i
            );
            bytes memory sig = _sign(intent);
            vm.prank(agent);
            boundary.executeAuthorizedAgentCall(intent, payload, sig);
        }

        uint256 spent = _spentToday();
        emit log_named_uint("GAP-1 NATIVE: totalSpentToday after 10 zero-value intents", spent);

        if (spent >= 1000 ether) {
            emit log("GAP-1 NATIVE CONFIRMED: Daily limit filled by zero-value intents (DoS)");
        } else {
            emit log("GAP-1 NATIVE NOT CONFIRMED: Daily limit not filled");
        }

        // Try legitimate native settlement with value
        vm.deal(agent, 200 ether);
        bytes memory legitPayload = abi.encodeWithSelector(NativeGapRecorder.record.selector);
        AkmenaExecutionAuthorization.ExecutionIntent memory legitIntent = _nativeIntent(
            address(recorder), legitPayload, NativeGapRecorder.record.selector, 50 ether, 50 ether, 10
        );
        bytes memory legitSig = _sign(legitIntent);
        vm.prank(agent);
        try boundary.executeAuthorizedAgentCall{value: 50 ether}(legitIntent, legitPayload, legitSig) {
            emit log("GAP-1 NATIVE: Legitimate settlement SUCCEEDED");
        } catch {
            emit log("GAP-1 NATIVE: Legitimate settlement BLOCKED (DoS confirmed)");
        }
    }

    /// @notice GAP-2: Native intent to non-allowlisted target (with policy set).
    function test_GAP2_NativeBypassesAllowlistWithPolicy() public {
        vm.deal(agent, 10 ether);
        bytes memory payload = abi.encodeWithSelector(NativeGapRecorder.record.selector);

        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _nativeIntent(
            address(recorder), // NOT allowlisted (native has no allowlist)
            payload,
            NativeGapRecorder.record.selector,
            1 ether,
            1 ether,
            50
        );
        bytes memory sig = _sign(intent);

        vm.prank(agent);
        try boundary.executeAuthorizedAgentCall{value: 1 ether}(intent, payload, sig) {
            emit log("GAP-2 CONFIRMED: Native intent to non-allowlisted target SUCCEEDED");
            assertEq(recorder.callCount(), 1);
        } catch (bytes memory err) {
            emit log("GAP-2: Native intent REVERTED");
            emit log_bytes(err);
        }
    }
}
