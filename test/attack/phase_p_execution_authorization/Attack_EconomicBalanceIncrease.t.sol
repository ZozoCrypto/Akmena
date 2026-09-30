// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaCore} from "../../../src/core/AkmenaCore.sol";
import {AkmenaPolicyBoundary} from "../../../src/authorization/AkmenaPolicyBoundary.sol";
import {AkmenaExecutionAuthorization} from "../../../src/authorization/AkmenaExecutionAuthorization.sol";
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

/// @notice Push-style adapter: the boundary pushes intent.amount here
/// before invoking the payload. The adapter then triggers a token-side
/// balance increase for the boundary mid-call (simulates rebase /
/// reflection crediting holders during the execution window).
/// The boundary grants no pull allowances, so the adapter cannot take
/// anything beyond the push.
contract RebasePushAdapter {
    function receiveAndRebase(address token, uint256 rebaseAmt) external {
        // The boundary already pushed intent.amount to this adapter before
        // this call. Minting to the boundary simulates the rebase credit.
        RebaseToken(token).rebaseMint(msg.sender, rebaseAmt);
    }
}

/// @notice Model D regression tests for the removed EconomicBalanceIncrease
/// guard.
///
/// Under the old measurement model, a net balance INCREASE during the
/// ERC20 execution window had to revert, because balance-delta accounting
/// could otherwise be distorted (net-zero and partial-credit flows were
/// invisible to it).
///
/// Under Model D there is no balance-delta measurement: settlement pulls
/// exactly intent.amount from the operator, pushes exactly intent.amount
/// to the allowlisted adapter, and the charge (totalSpentToday) is fixed
/// BEFORE any fund movement. A mid-call mint therefore cannot distort
/// the charge — it is stranded in the boundary by design (no sweep) and
/// never reduces the recorded spend.
contract Attack_EconomicBalanceIncrease is Test {
    AkmenaCore internal core;
    AkmenaPolicyBoundary internal boundary;
    AkmenaExecutionAuthorization internal auth;
    RebaseToken internal token;
    RebasePushAdapter internal adapter;

    uint256 internal constant AGENT_KEY = 0xA11CE;
    address internal agent;

    uint256 internal nonceCounter;

    function setUp() public {
        agent = vm.addr(AGENT_KEY);

        core = new AkmenaCore(); // test contract IS core.deployer()
        boundary = new AkmenaPolicyBoundary(address(core));
        auth = boundary.executionAuthorization();

        token = new RebaseToken();
        adapter = new RebasePushAdapter();

        boundary.setAgentAssetPolicy(agent, address(token), 1000 ether, 10000 ether, false);
        boundary.setEconomicAdapter(address(token), address(adapter), true);
        boundary.setStandardDebit(address(token), true);

        // Model D: the operator (this test contract) funds itself and
        // approves the boundary. The boundary never holds pooled funds and
        // never grants pull allowances.
        token.mint(address(this), 1000 ether);
        token.approve(address(boundary), type(uint256).max);
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

    /// @notice Model D property: a token-side mint to the boundary mid-call
    /// cannot distort the charge. The charge is fixed at intent.amount
    /// before any fund movement; the rebase is stranded in the boundary
    /// (no sweep by design) and never reduces recorded spend.
    function test_rebaseMintCannotDistortCharge() public {
        bytes memory payload = abi.encodeWithSelector(
            RebasePushAdapter.receiveAndRebase.selector, address(token), 200 ether
        );
        AkmenaExecutionAuthorization.ExecutionIntent memory intent =
            _intent(address(adapter), payload, address(token), 100 ether);
        bytes memory sig = _sign(intent);

        uint256 operatorBefore = token.balanceOf(address(this));

        vm.prank(agent);
        boundary.executeAuthorizedAgentCall(intent, payload, sig);

        // Charge is exactly the authorized amount, unaffected by the rebase.
        assertEq(_totalSpent(address(token)), 100 ether, "charge fixed at intent.amount");
        // Adapter received exactly the pushed amount — no more, no less.
        assertEq(token.balanceOf(address(adapter)), 100 ether, "adapter received exactly 100");
        // Operator funded exactly the authorized amount.
        assertEq(token.balanceOf(address(this)), operatorBefore - 100 ether, "operator debited exactly 100");
        // The mid-call rebase mint is stranded in the boundary; it does NOT
        // reduce the recorded charge.
        assertEq(token.balanceOf(address(boundary)), 200 ether, "rebase stranded, charge unaffected");
    }

    /// @notice Model D happy-path control: operator approves + funds, the
    /// allowlisted adapter receives exactly the pushed amount, the charge
    /// is exact, and the boundary ends with zero residual balance.
    function test_modelDSettlementHappyPath() public {
        bytes memory payload = abi.encodeWithSelector(
            RebasePushAdapter.receiveAndRebase.selector, address(token), 0
        );
        AkmenaExecutionAuthorization.ExecutionIntent memory intent =
            _intent(address(adapter), payload, address(token), 100 ether);
        bytes memory sig = _sign(intent);

        uint256 operatorBefore = token.balanceOf(address(this));

        vm.prank(agent);
        boundary.executeAuthorizedAgentCall(intent, payload, sig);

        assertEq(token.balanceOf(address(adapter)), 100 ether, "adapter received exactly 100");
        assertEq(token.balanceOf(address(boundary)), 0, "no residual boundary balance");
        assertEq(token.balanceOf(address(this)), operatorBefore - 100 ether, "operator debited exactly 100");
        assertEq(_totalSpent(address(token)), 100 ether, "charge recorded exactly");
    }
}
