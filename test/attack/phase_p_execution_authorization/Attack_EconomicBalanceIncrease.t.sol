// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaCore} from "../../../src/core/AkmenaCore.sol";
import {AkmenaPolicyBoundary} from "../../../src/authorization/AkmenaPolicyBoundary.sol";
import {AkmenaExecutionAuthorization} from "../../../src/authorization/AkmenaExecutionAuthorization.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @notice Plain mock ERC20 with an open mint, used to simulate an
/// elastic-supply rebase / reflection payout mid-execution.
contract RebaseToken is ERC20 {
    constructor() ERC20("Rebase", "RBS") {}

    function mint(address to, uint256 amt) external {
        _mint(to, amt);
    }

    function rebaseMint(address to, uint256 amt) external {
        _mint(to, amt);
    }
}

/// @notice Adapter that pulls `amt` tokens from the caller (the
/// PolicyBoundary) to `to`, then triggers a token-side balance increase
/// for the boundary (simulates rebase/reflection crediting holders
/// during the execution window).
contract RebasePullAdapter {
    function pullAndRebase(address token, address to, uint256 amt, uint256 rebaseAmt) external {
        IERC20(token).transferFrom(msg.sender, to, amt);
        RebaseToken(token).rebaseMint(msg.sender, rebaseAmt);
    }
}

/// @notice Regression tests for the EconomicBalanceIncrease guard:
/// a net balance INCREASE during the ERC20 execution window must revert
/// instead of being silently absorbed into a zero-spend reading.
///
/// Residual (tracked separately, NOT fixed): net-zero (pull X + mint X)
/// and partial-credit (pull 100 + mint 30) flows are invisible to
/// net-delta accounting.
contract Attack_EconomicBalanceIncrease is Test {
    AkmenaCore internal core;
    AkmenaPolicyBoundary internal boundary;
    AkmenaExecutionAuthorization internal auth;
    RebaseToken internal token;
    RebasePullAdapter internal adapter;

    address internal recipient = address(0xBEE);

    uint256 internal constant AGENT_KEY = 0xA11CE;
    address internal agent;

    uint256 internal nonceCounter;

    function setUp() public {
        agent = vm.addr(AGENT_KEY);

        core = new AkmenaCore(); // test contract IS core.deployer()
        boundary = new AkmenaPolicyBoundary(address(core));
        auth = boundary.executionAuthorization();

        token = new RebaseToken();
        adapter = new RebasePullAdapter();

        boundary.setAgentAssetPolicy(agent, address(token), 1000 ether, 10000 ether, false);
        boundary.setEconomicAdapter(address(token), address(adapter), true);
        vm.prank(address(boundary));
        token.approve(address(adapter), type(uint256).max);

        token.mint(address(boundary), 1000 ether);
    }

    function _intent(address target, bytes memory payload, address asset, uint256 amount)
        internal
        returns (AkmenaExecutionAuthorization.ExecutionIntent memory intent)
    {
        intent = AkmenaExecutionAuthorization.ExecutionIntent({
            operator: address(this),
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

    function _totalSpent(address asset) internal view returns (uint256) {
        (,, uint256 totalSpentToday,,) =
            boundary.agentAssetPolicies(address(this), agent, asset);
        return totalSpentToday;
    }

    /// @notice The attack: adapter pulls 100 out while the token mints 200
    /// back to the boundary mid-call (net: boundary 1000 -> 1100).
    /// Must revert with EconomicBalanceIncrease(), atomically: balances
    /// and daily spend unchanged.
    function test_balanceIncreaseRevertsAtomically() public {
        bytes memory payload = abi.encodeWithSelector(
            RebasePullAdapter.pullAndRebase.selector, address(token), recipient, 100 ether, 200 ether
        );
        AkmenaExecutionAuthorization.ExecutionIntent memory intent =
            _intent(address(adapter), payload, address(token), 100 ether);
        bytes memory sig = _sign(intent); // sign BEFORE expectRevert: hashIntent is an external call

        vm.expectRevert(AkmenaPolicyBoundary.EconomicBalanceIncrease.selector);
        vm.prank(agent);
        boundary.executeAuthorizedAgentCall(intent, payload, sig);

        assertEq(token.balanceOf(address(boundary)), 1000 ether, "boundary balance unchanged");
        assertEq(token.balanceOf(recipient), 0, "recipient received nothing");
        assertEq(_totalSpent(address(token)), 0, "no spend recorded");
    }

    /// @notice Control: a plain pull with NO rebase still works and records
    /// measured spend exactly (guard must not break the happy path).
    function test_plainPullStillWorks() public {
        bytes memory payload = abi.encodeWithSelector(
            RebasePullAdapter.pullAndRebase.selector, address(token), recipient, 100 ether, 0
        );
        AkmenaExecutionAuthorization.ExecutionIntent memory intent =
            _intent(address(adapter), payload, address(token), 100 ether);
        bytes memory sig = _sign(intent);

        vm.prank(agent);
        boundary.executeAuthorizedAgentCall(intent, payload, sig);

        assertEq(token.balanceOf(address(boundary)), 900 ether, "boundary -100");
        assertEq(token.balanceOf(recipient), 100 ether, "recipient +100");
        assertEq(_totalSpent(address(token)), 100 ether, "measured spend recorded");
    }
}
