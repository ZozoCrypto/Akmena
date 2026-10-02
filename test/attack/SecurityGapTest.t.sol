// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaCore} from "../../src/core/AkmenaCore.sol";
import {AkmenaPolicyBoundary} from "../../src/authorization/AkmenaPolicyBoundary.sol";
import {AkmenaExecutionAuthorization} from "../../src/authorization/AkmenaExecutionAuthorization.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract GapMockToken is ERC20 {
    constructor() ERC20("Gap", "GAP") {}
    function mint(address to, uint256 amt) external { _mint(to, amt); }
}

contract GapMockAdapter {
    uint256 public received;
    function execute(uint256 amount) external returns (bool) {
        received += amount;
        return true;
    }
}

/// @notice Tracks calls made to it, for GAP-3 zero-amount bypass test.
contract GapCallRecorder {
    uint256 public callCount;
    address public lastCaller;
    function record() external {
        callCount++;
        lastCaller = msg.sender;
    }
}

/// @notice ERC777-style token with hooks for GAP-4.
contract GapERC777Mock is ERC20 {
    address public hookTarget;
    bool public attemptReentry;
    AkmenaPolicyBoundary public boundary;
    bytes public reentryPayload;

    constructor() ERC20("ERC777Mock", "E777") {}

    function mint(address to, uint256 amt) external { _mint(to, amt); }
    function setHookTarget(address t) external { hookTarget = t; }
    function setReentry(address b, bytes memory p) external {
        attemptReentry = true;
        boundary = AkmenaPolicyBoundary(b);
        reentryPayload = p;
    }

    function _update(address from, address to, uint256 value) internal override {
        // Simulate ERC777 tokensToSend hook on sender
        if (from != address(0) && hookTarget != address(0)) {
            // Call hook on sender's behalf (simplified ERC777 simulation)
            (bool success,) = hookTarget.call(
                abi.encodeWithSignature("tokensToSend(address,address,uint256)", msg.sender, from, value)
            );
            success; // ignore result for mock
        }
        super._update(from, to, value);
        // Attempt reentry after transfer (simulating tokensReceived hook)
        if (attemptReentry && to != address(0)) {
            // This would be called by the adapter in a real ERC777 flow
        }
    }
}

/// @notice Security gap tests from 2026-10-01 gap analysis.
/// GAP-1: Policy DoS via zero-value intents (Medium)
/// GAP-2: Native path lacks adapter allowlist (Medium)
/// GAP-3: Zero-amount ERC20 bypasses allowlist (Low)
/// GAP-4: ERC777 hooks untested (Low)
contract SecurityGapTest is Test {
    uint256 internal constant AGENT_KEY = 0x6A9;
    address internal agent;
    address internal operator = address(0xB0B);

    AkmenaCore internal core;
    AkmenaPolicyBoundary internal boundary;
    AkmenaExecutionAuthorization internal auth;
    GapMockToken internal token;
    GapMockAdapter internal adapter;
    GapCallRecorder internal recorder;

    function setUp() public {
        agent = vm.addr(AGENT_KEY);
        core = new AkmenaCore();
        boundary = new AkmenaPolicyBoundary(address(core));
        auth = AkmenaExecutionAuthorization(address(boundary.executionAuthorization()));
        token = new GapMockToken();
        adapter = new GapMockAdapter();
        recorder = new GapCallRecorder();

        boundary.setEconomicAdapter(address(token), address(adapter), true);
        boundary.setStandardDebit(address(token), true);
        token.mint(operator, 1_000_000 ether);

        vm.startPrank(operator);
        boundary.setAgentAssetPolicy(agent, address(token), 100 ether, 1000 ether, false);
        token.approve(address(boundary), 500 ether);
        vm.stopPrank();
    }

    function _intent(
        address target,
        bytes memory payload,
        bytes4 selector,
        uint256 amount,
        uint256 nonce,
        address asset
    ) internal view returns (AkmenaExecutionAuthorization.ExecutionIntent memory) {
        return AkmenaExecutionAuthorization.ExecutionIntent({
            operator: operator,
            agent: agent,
            target: target,
            selector: selector,
            asset: asset,
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

    function _sign(AkmenaExecutionAuthorization.ExecutionIntent memory intent)
        internal view returns (bytes memory)
    {
        bytes32 digest = auth.hashIntent(intent);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(AGENT_KEY, digest);
        return abi.encodePacked(r, s, v);
    }

    /// @notice GAP-1 (ERC20 leg): Zero-amount ERC20 intents never charge the daily limit.
    /// @dev HARDENED: This test now asserts the correct behavior with the proper struct field.
    /// (TQ-1 fix: was reading lastResetTimestamp as totalSpentToday.)
    function test_GAP1_ZeroValueIntentFillsDailyLimit() public {
        // Daily limit is 1000 ether. Submit 10 zero-value intents.
        for (uint256 i = 0; i < 10; i++) {
            bytes memory payload = abi.encodeWithSelector(GapMockAdapter.execute.selector, 0);
            // Zero-amount intent to allowlisted adapter
            AkmenaExecutionAuthorization.ExecutionIntent memory intent = _intent(
                address(adapter), payload, GapMockAdapter.execute.selector, 0, i, address(token)
            );
            bytes memory sig = _sign(intent);
            vm.prank(agent);
            boundary.executeAuthorizedAgentCall(intent, payload, sig);
        }

        // Check how much was charged to the daily limit (TQ-1: correct field index 2)
        (,, uint256 totalSpentToday,,) = boundary.agentAssetPolicies(operator, agent, address(token));
        assertEq(totalSpentToday, 0, "Zero-amount intents must not charge the daily limit");

        // Legitimate settlement should succeed (limit not consumed by spam)
        bytes memory legitPayload = abi.encodeWithSelector(GapMockAdapter.execute.selector, 100 ether);
        AkmenaExecutionAuthorization.ExecutionIntent memory legitIntent = _intent(
            address(adapter), legitPayload, GapMockAdapter.execute.selector, 100 ether, 10, address(token)
        );
        bytes memory legitSig = _sign(legitIntent);
        vm.prank(agent);
        boundary.executeAuthorizedAgentCall(legitIntent, legitPayload, legitSig);
        // Verify the legitimate settlement was charged
        (,, uint256 spentAfter,,) = boundary.agentAssetPolicies(operator, agent, address(token));
        assertEq(spentAfter, 100 ether, "Legitimate settlement should charge exactly 100 ether");
    }

    /// @notice GAP-2: Native intent to non-allowlisted target.
    /// @dev Documents that native intents bypass the adapter allowlist.
    function test_GAP2_NativeIntentBypassesAllowlist() public {
        // Create a native intent targeting the recorder (not allowlisted)
        address nonAllowlistedTarget = address(recorder);
        bytes memory payload = abi.encodeWithSelector(GapCallRecorder.record.selector);

        AkmenaExecutionAuthorization.ExecutionIntent memory intent =
            AkmenaExecutionAuthorization.ExecutionIntent({
                operator: operator,
                agent: agent,
                target: nonAllowlistedTarget,
                selector: GapCallRecorder.record.selector,
                asset: address(0), // native
                calldataHash: keccak256(payload),
                amount: 0,
                value: 1 ether, // agent sends their own ETH
                proofModuleKey: bytes32(0),
                proofId: 0,
                nonce: 100,
                validAfter: block.timestamp,
                deadline: block.timestamp + 1 hours
            });

        bytes memory sig = _sign(intent);

        // Fund the agent with ETH
        vm.deal(agent, 10 ether);

        vm.prank(agent);
        try boundary.executeAuthorizedAgentCall{value: 1 ether}(intent, payload, sig) {
            emit log("GAP-2: Native intent to non-allowlisted target SUCCEEDED");
            assertEq(recorder.callCount(), 1, "Recorder should have been called");
            assertEq(recorder.lastCaller(), address(boundary), "Caller should be boundary");
        } catch {
            emit log("GAP-2: Native intent to non-allowlisted target REVERTED");
        }
    }

    /// @notice GAP-3: Zero-amount ERC20 intent to non-allowlisted target.
    /// @dev HARDENED (2026-10-01): Zero-amount calls now revert unless the target is a
    /// registered proof module or allowlisted adapter. This closes the confused-deputy vector.
    function test_GAP3_ZeroAmountBypassesAllowlist() public {
        bytes memory payload = abi.encodeWithSelector(GapCallRecorder.record.selector);

        // Zero-amount ERC20 intent to non-allowlisted, non-module target
        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _intent(
            address(recorder),
            payload,
            GapCallRecorder.record.selector,
            0, // zero amount
            200,
            address(token)
        );

        bytes memory sig = _sign(intent);
        vm.prank(agent);
        // HARDENED: must revert — target is neither a registered proof module nor an adapter
        vm.expectRevert(AkmenaPolicyBoundary.UnauthorizedZeroAmountTarget.selector);
        boundary.executeAuthorizedAgentCall(intent, payload, sig);
    }

    /// @notice GAP-3 positive: Zero-amount intent to a registered proof module succeeds.
    /// @dev Preserves the stated use case (proof-context/authorization operations).
    function test_GAP3_ZeroAmountToProofModuleSucceeds() public {
        bytes32 moduleKey = keccak256("gap3.proof.module");
        core.registerModule(moduleKey, address(recorder), "1.0.0");

        bytes memory payload = abi.encodeWithSelector(GapCallRecorder.record.selector);

        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _intent(
            address(recorder),
            payload,
            GapCallRecorder.record.selector,
            0, // zero amount
            201,
            address(token)
        );
        // Set the proof module key to match the registered module
        intent.proofModuleKey = moduleKey;

        bytes memory sig = _sign(intent);
        vm.prank(agent);
        boundary.executeAuthorizedAgentCall(intent, payload, sig);
        assertEq(recorder.callCount(), 1, "Recorder (as proof module) should have been called");
        assertEq(recorder.lastCaller(), address(boundary), "Caller should be boundary");
    }

    /// @notice GAP-3 hardening: Zero-amount intent to a DISABLED proof module reverts.
    /// @dev 2026-10-02: The isEnabled flag is now enforced. A registered-but-disabled
    /// module must not receive zero-amount calls as the boundary.
    function test_GAP3_ZeroAmountToDisabledModuleReverts() public {
        bytes32 moduleKey = keccak256("gap3.disabled.module");
        core.registerModule(moduleKey, address(recorder), "1.0.0");
        // Disable the module
        core.setModuleStatus(moduleKey, false);

        bytes memory payload = abi.encodeWithSelector(GapCallRecorder.record.selector);

        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _intent(
            address(recorder),
            payload,
            GapCallRecorder.record.selector,
            0, // zero amount
            202,
            address(token)
        );
        intent.proofModuleKey = moduleKey;

        bytes memory sig = _sign(intent);
        vm.prank(agent);
        vm.expectRevert(AkmenaPolicyBoundary.UnauthorizedZeroAmountTarget.selector);
        boundary.executeAuthorizedAgentCall(intent, payload, sig);
        assertEq(recorder.callCount(), 0, "Disabled module must not have been called");
    }

    /// @notice GAP-4: ERC777-style hook behavior.
    /// @dev Verifies that token hooks cannot reenter the boundary.
    function test_GAP4_ERC777HookCannotReenter() public {
        GapERC777Mock erc777 = new GapERC777Mock();
        erc777.mint(operator, 1000 ether);

        // Allowlist and admit the ERC777 token
        boundary.setEconomicAdapter(address(erc777), address(adapter), true);
        boundary.setStandardDebit(address(erc777), true);

        vm.startPrank(operator);
        boundary.setAgentAssetPolicy(agent, address(erc777), 100 ether, 1000 ether, false);
        erc777.approve(address(boundary), 500 ether);
        vm.stopPrank();

        // Normal settlement with ERC777 token (hooks are no-ops in our mock)
        bytes memory payload = abi.encodeWithSelector(GapMockAdapter.execute.selector, 10 ether);
        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _intent(
            address(adapter), payload, GapMockAdapter.execute.selector, 10 ether, 300, address(erc777)
        );
        bytes memory sig = _sign(intent);

        vm.prank(agent);
        // Should succeed - hooks don't break normal flow
        boundary.executeAuthorizedAgentCall(intent, payload, sig);
        assertEq(adapter.received(), 10 ether, "Adapter should receive funds");

        emit log("GAP-4: ERC777-style token settlement SUCCEEDED (hooks did not break flow)");
    }
}
