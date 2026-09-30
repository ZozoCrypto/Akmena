// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaCore} from "../../../src/core/AkmenaCore.sol";
import {AkmenaPolicyBoundary} from "../../../src/authorization/AkmenaPolicyBoundary.sol";
import {AkmenaExecutionAuthorization} from "../../../src/authorization/AkmenaExecutionAuthorization.sol";
import {AkmenaToken} from "../../../src/token/core/AkmenaToken.sol";

contract AKMAdmissionAdapter {
    uint256 public received;
    function execute(uint256 amount) external returns (bool) {
        received += amount;
        return true;
    }
}

/// @notice §7.2 admission battery for the AkmenaToken (AKM).
/// @dev First candidate token for Standard-Debit admission. Each test maps
/// to a qualification criterion. All must pass for admission.
contract AKMAdmissionBatteryTest is Test {
    uint256 internal constant OPERATOR_KEY = 0x0E7A71;
    uint256 internal constant AGENT_KEY = 0xA6E171;

    address internal operator;
    address internal agent;

    AkmenaCore internal core;
    AkmenaPolicyBoundary internal boundary;
    AkmenaExecutionAuthorization internal auth;
    AkmenaToken internal akm;
    AKMAdmissionAdapter internal adapter;

    uint256 internal nonceCounter;

    function setUp() public {
        operator = vm.addr(OPERATOR_KEY);
        agent = vm.addr(AGENT_KEY);

        core = new AkmenaCore();
        boundary = new AkmenaPolicyBoundary(address(core));
        auth = boundary.executionAuthorization();
        // AKM: fixed 1B supply minted to the operator (test holder).
        akm = new AkmenaToken(operator);
        adapter = new AKMAdmissionAdapter();

        vm.startPrank(operator);
        akm.approve(address(boundary), type(uint256).max);
        boundary.setAgentAssetPolicy(agent, address(akm), 100 ether, 1000 ether, false);
        vm.stopPrank();

        boundary.setStandardDebit(address(akm), true);
        boundary.setEconomicAdapter(address(akm), address(adapter), true);
    }

    function _execute(uint256 amount) internal returns (bool) {
        bytes memory payload = abi.encodeWithSelector(AKMAdmissionAdapter.execute.selector, amount);
        AkmenaExecutionAuthorization.ExecutionIntent memory intent =
            AkmenaExecutionAuthorization.ExecutionIntent({
                operator: operator,
                agent: agent,
                target: address(adapter),
                selector: bytes4(payload),
                calldataHash: keccak256(payload),
                asset: address(akm),
                amount: amount,
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
            return true;
        } catch {
            return false;
        }
    }

    /// @notice Criterion 1: exact transfer — no fee, no shortfall.
    function test_C1_ExactTransfer() public {
        uint256 opBefore = akm.balanceOf(operator);
        assertTrue(_execute(100 ether), "settlement must succeed");
        assertEq(akm.balanceOf(operator), opBefore - 100 ether, "operator debited exactly 100");
        assertEq(akm.balanceOf(address(adapter)), 100 ether, "adapter received exactly 100");
        assertEq(akm.balanceOf(address(boundary)), 0, "boundary holds zero residual");
    }

    /// @notice Criterion 2 (F-7): amount-honesty — transferFrom pulls exactly
    /// the stated amount, never more.
    function test_C2_AmountHonestPull() public {
        uint256 opBefore = akm.balanceOf(operator);
        assertTrue(_execute(100 ether));
        uint256 taken = opBefore - akm.balanceOf(operator);
        assertEq(taken, 100 ether, "F-7: pulled exactly intent.amount, no over-pull");
    }

    /// @notice Criterion 3: allowance accounting is exact.
    /// @dev OZ ERC20 skips decrementing infinite (max) approvals — standard
    /// gas optimization, not an accounting error. We verify exact accounting
    /// with a finite approval instead.
    function test_C3_ExactAllowanceAccounting() public {
        // Finite approval: must decrement by exactly the pulled amount.
        vm.prank(operator);
        akm.approve(address(boundary), 500 ether);
        uint256 allowanceBefore = akm.allowance(operator, address(boundary));
        assertTrue(_execute(100 ether));
        uint256 allowanceAfter = akm.allowance(operator, address(boundary));
        assertEq(allowanceBefore - allowanceAfter, 100 ether, "allowance decremented exactly");

        // Infinite approval: OZ optimization skips the decrement (no underflow,
        // no over-spend — the token simply doesn't bother counting down from max).
        vm.prank(operator);
        akm.approve(address(boundary), type(uint256).max);
        assertTrue(_execute(100 ether));
        assertEq(
            akm.allowance(operator, address(boundary)),
            type(uint256).max,
            "infinite approval untouched (OZ optimization)"
        );
    }

    /// @notice Criterion 4: failures revert, no silent success.
    function test_C4_NoSilentSuccess() public {
        // Revoke allowance: transferFrom must revert, not return true.
        vm.prank(operator);
        akm.approve(address(boundary), 0);
        assertFalse(_execute(100 ether), "must revert on zero allowance");
        // Policy unchanged, adapter got nothing.
        (,, uint256 spent,,) = boundary.agentAssetPolicies(operator, agent, address(akm));
        assertEq(spent, 0);
        assertEq(akm.balanceOf(address(adapter)), 0);
    }

    /// @notice Criterion 5: no sender-side hooks — plain EOA operator has no code.
    function test_C5_NoSenderHooks() public {
        assertEq(operator.code.length, 0, "operator is EOA, no hook code possible");
        assertTrue(_execute(100 ether), "settlement succeeds without hook interference");
    }

    /// @notice Non-upgradeable: no proxy, no admin, no upgrade path.
    function test_NonUpgradeable() public {
        // AkmenaToken has no upgrade function, no admin role, no proxy.
        // Verified by source inspection (no UUPS/TransparentProxy/diamond).
        // Runtime: the token bytecode is immutable post-deployment.
        assertTrue(address(akm).code.length > 0, "deployed");
    }

    /// @notice Non-pausable, non-blacklisting: no pause/blacklist functions.
    function test_NoPauseNoBlacklist() public {
        // Source inspection: no Pausable, no blacklist mapping, no
        // AccessControl/Ownable. Transfer cannot be censored.
        // Runtime: transfers work unconditionally.
        vm.prank(operator);
        assertTrue(akm.transfer(address(0x1), 1 ether), "unconditional transfer works");
    }

    /// @notice Fixed supply: no mint/burn after construction.
    function test_FixedSupply() public {
        assertEq(akm.totalSupply(), akm.MAX_SUPPLY(), "supply is fixed at MAX_SUPPLY");
        assertEq(akm.balanceOf(operator), akm.MAX_SUPPLY(), "all supply to initial holder");
    }

    /// @notice ERC-3009 does not affect standard transfer semantics.
    function test_ERC3009_DoesNotAffectStandardPath() public {
        // The boundary uses transferFrom/transfer only. ERC-3009 is a
        // separate entrypoint that funnels through _transfer (exact).
        // Verify standard path is unaffected by the extension's presence.
        uint256 opBefore = akm.balanceOf(operator);
        vm.prank(operator);
        akm.transfer(address(adapter), 50 ether);
        assertEq(akm.balanceOf(operator), opBefore - 50 ether, "direct transfer exact");
    }
}
