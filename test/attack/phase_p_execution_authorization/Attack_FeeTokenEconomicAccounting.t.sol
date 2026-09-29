// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaCore} from "../../../src/core/AkmenaCore.sol";
import {AkmenaPolicyBoundary} from "../../../src/authorization/AkmenaPolicyBoundary.sol";
import {AkmenaExecutionAuthorization} from "../../../src/authorization/AkmenaExecutionAuthorization.sol";
import {EscrowEngine} from "../../../src/economics/EscrowEngine.sol";
import {IEscrowEngine} from "../../../src/economics/IEscrowEngine.sol";
import {LibStorage} from "../../../src/storage/LibStorage.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @notice Mock ERC20 with a 10% fee-on-transfer, taken from the transferred
/// amount and routed to a configurable fee collector.
/// Fee is charged on every non-mint/non-burn transfer via _update override.
contract FeeToken is ERC20 {
    address public feeCollector;
    uint256 public constant FEE_BPS = 1000; // 10%

    constructor(address _feeCollector) ERC20("FeeToken", "FEE") {
        feeCollector = _feeCollector;
    }

    function mint(address to, uint256 amt) external {
        _mint(to, amt);
    }

    function setFeeCollector(address c) external {
        feeCollector = c;
    }

    function _update(address from, address to, uint256 value) internal override {
        if (from != address(0) && to != address(0) && feeCollector != address(0) && value > 0) {
            uint256 fee = (value * FEE_BPS) / 10_000;
            if (fee > 0) {
                super._update(from, to, value - fee);
                super._update(from, feeCollector, fee);
                return;
            }
        }
        super._update(from, to, value);
    }
}

/// @notice Plain mock ERC20 (no fee) for the escrow control cases.
contract PlainToken is ERC20 {
    constructor() ERC20("Plain", "PLN") {}

    function mint(address to, uint256 amt) external {
        _mint(to, amt);
    }
}

/// @notice Benign economic adapter: pulls `amt` tokens from the caller
/// (the PolicyBoundary) to `to`.
contract PullAdapter {
    function pull(address token, address to, uint256 amt) external {
        IERC20(token).transferFrom(msg.sender, to, amt);
    }
}

/// @notice Fee-on-transfer token vs balance-delta accounting.
/// Covers (a) PolicyBoundary execution path: measured spend records the net
/// outflow from boundary custody, never the declared amount;
/// (b) EscrowEngine funding path: fee tokens are rejected, plain tokens fund cleanly;
/// (c) fee-to-boundary and fee-to-third-party edges.
contract Attack_FeeTokenEconomicAccounting is Test {
    AkmenaCore internal core;
    AkmenaPolicyBoundary internal boundary;
    AkmenaExecutionAuthorization internal auth;
    EscrowEngine internal escrowEngine;
    FeeToken internal feeToken;
    PlainToken internal plainToken;
    PullAdapter internal adapter;

    address internal feeCollector = address(0xFEE);
    address internal recipient = address(0xBEE);

    uint256 internal constant AGENT_KEY = 0xA11CE;
    address internal agent;

    uint256 internal nonceCounter;

    function setUp() public {
        agent = vm.addr(AGENT_KEY);

        core = new AkmenaCore(); // test contract IS core.deployer()
        boundary = new AkmenaPolicyBoundary(address(core));
        auth = boundary.executionAuthorization();

        feeToken = new FeeToken(feeCollector);
        plainToken = new PlainToken();
        adapter = new PullAdapter();

        escrowEngine = new EscrowEngine(address(plainToken));

        // Operator policy for the fee token: max 1000/tx, 10000/day.
        boundary.setAgentAssetPolicy(agent, address(feeToken), 1000 ether, 10000 ether, false);
        // Allowlist the adapter for the fee token (test contract is deployer).
        boundary.setEconomicAdapter(address(feeToken), address(adapter), true);
        // Boundary pre-approves the adapter.
        vm.prank(address(boundary));
        feeToken.approve(address(adapter), type(uint256).max);

        // Fund the boundary with 1000 fee-tokens (mint = no fee).
        feeToken.mint(address(boundary), 1000 ether);
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

    function _execute(AkmenaExecutionAuthorization.ExecutionIntent memory intent, bytes memory payload)
        internal
        returns (bytes memory)
    {
        bytes memory sig = _sign(intent);
        vm.prank(agent);
        return boundary.executeAuthorizedAgentCall(intent, payload, sig);
    }

    function _totalSpent(address asset) internal view returns (uint256) {
        (,, uint256 totalSpentToday,,) =
            boundary.agentAssetPolicies(address(this), agent, asset);
        return totalSpentToday;
    }

    /*//////////////////////////////////////////////////////////////
                              (a) BOUNDARY
    //////////////////////////////////////////////////////////////*/

    /// @notice Baseline: intent amount=100, adapter pulls 100 fee-tokens.
    /// Measured spend is the full 100 outflow even though the recipient
    /// receives only 90 after the 10% fee.
    function test_a_feeTokenMeasuredSpendExact() public {
        bytes memory payload =
            abi.encodeWithSelector(PullAdapter.pull.selector, address(feeToken), recipient, 100 ether);
        AkmenaExecutionAuthorization.ExecutionIntent memory intent =
            _intent(address(adapter), payload, address(feeToken), 100 ether);

        uint256 bBefore = feeToken.balanceOf(address(boundary));
        uint256 rBefore = feeToken.balanceOf(recipient);
        uint256 cBefore = feeToken.balanceOf(feeCollector);

        _execute(intent, payload);

        uint256 spent = bBefore - feeToken.balanceOf(address(boundary));
        uint256 rDelta = feeToken.balanceOf(recipient) - rBefore;
        uint256 cDelta = feeToken.balanceOf(feeCollector) - cBefore;

        assertEq(bBefore, 1000 ether, "boundary funded with 1000");
        assertEq(spent, 100 ether, "measured spend = full 100 outflow");
        assertEq(rDelta, 90 ether, "recipient receives 90 after 10% fee");
        assertEq(cDelta, 10 ether, "collector receives the 10 fee");
        assertEq(_totalSpent(address(feeToken)), 100 ether, "daily total records 100");
    }

    /// @notice Ceiling check: intent amount=90 but adapter pulls 100.
    /// Measured outflow (100) exceeds the declared ceiling (90) -> must revert.
    function test_a_measuredSpendExceedsIntentReverts() public {
        bytes memory payload =
            abi.encodeWithSelector(PullAdapter.pull.selector, address(feeToken), recipient, 100 ether);
        AkmenaExecutionAuthorization.ExecutionIntent memory intent =
            _intent(address(adapter), payload, address(feeToken), 90 ether);

        bytes memory sig = _sign(intent); // sign BEFORE expectRevert: hashIntent is an external call
        vm.prank(agent);
        vm.expectRevert(AkmenaPolicyBoundary.EconomicSpendExceedsIntent.selector);
        boundary.executeAuthorizedAgentCall(intent, payload, sig);

        assertEq(feeToken.balanceOf(address(boundary)), 1000 ether, "no state changed on revert");
        assertEq(_totalSpent(address(feeToken)), 0, "no spend recorded on revert");
    }

    /// @notice Distortion probe: two sequential 100-token executions.
    /// Accounting stays exact: 200 of budget consumed, 180 delivered.
    function test_a_repeatedSpendBudgetRatio() public {
        for (uint256 i = 0; i < 2; i++) {
            bytes memory payload =
                abi.encodeWithSelector(PullAdapter.pull.selector, address(feeToken), recipient, 100 ether);
            _execute(_intent(address(adapter), payload, address(feeToken), 100 ether), payload);
        }

        uint256 spent = 1000 ether - feeToken.balanceOf(address(boundary));
        uint256 received = feeToken.balanceOf(recipient);

        assertEq(spent, 200 ether, "measured spend exactly 200");
        assertEq(received, 180 ether, "recipient got 180 (90%)");
        assertEq(_totalSpent(address(feeToken)), 200 ether, "daily budget consumed 200");
    }

    /// @notice Edge (c1): fee routed to the BOUNDARY itself.
    /// Net outflow is 90; measured spend must be exactly 90, not 100.
    function test_c_feeToBoundaryItself() public {
        feeToken.setFeeCollector(address(boundary));

        bytes memory payload =
            abi.encodeWithSelector(PullAdapter.pull.selector, address(feeToken), recipient, 100 ether);
        AkmenaExecutionAuthorization.ExecutionIntent memory intent =
            _intent(address(adapter), payload, address(feeToken), 100 ether);

        uint256 bBefore = feeToken.balanceOf(address(boundary));
        _execute(intent, payload);
        uint256 spent = bBefore - feeToken.balanceOf(address(boundary));

        assertEq(spent, 90 ether, "measured spend = net 90 outflow");
        assertEq(feeToken.balanceOf(recipient), 90 ether, "recipient got 90");
        assertEq(_totalSpent(address(feeToken)), 90 ether, "daily total records 90");
    }

    /// @notice Edge (c2): fee routed to a third party.
    /// Pins the third-party split: 100 of budget consumed, 90 delivered,
    /// 10 to the third party.
    function test_c_feeToThirdParty() public {
        address thirdParty = address(0x7A7A);
        feeToken.setFeeCollector(thirdParty);

        bytes memory payload =
            abi.encodeWithSelector(PullAdapter.pull.selector, address(feeToken), recipient, 100 ether);
        _execute(_intent(address(adapter), payload, address(feeToken), 100 ether), payload);

        assertEq(1000 ether - feeToken.balanceOf(address(boundary)), 100 ether);
        assertEq(feeToken.balanceOf(thirdParty), 10 ether, "third party got the fee");
        assertEq(feeToken.balanceOf(recipient), 90 ether);
        assertEq(_totalSpent(address(feeToken)), 100 ether);
    }

    /*//////////////////////////////////////////////////////////////
                               (b) ESCROW
    //////////////////////////////////////////////////////////////*/

    /// @notice Fee token through the real-custody funding flow:
    /// declared 100, but only 90 arrives after the 10% fee.
    function test_b_escrowFeeTokenRejected() public {
        feeToken.mint(address(this), 100 ether);
        feeToken.approve(address(escrowEngine), 100 ether);

        vm.expectRevert(IEscrowEngine.EscrowFundingMismatch.selector);
        escrowEngine.createEscrow(address(this), recipient, address(feeToken), 100 ether);

        assertEq(feeToken.balanceOf(address(escrowEngine)), 0, "nothing left in the engine");
        assertEq(escrowEngine.totalLockedByAsset(address(feeToken)), 0, "no phantom liability");
    }

    /// @notice Control: plain token funds cleanly, records exactly 100.
    function test_b_escrowPlainTokenControl() public {
        plainToken.mint(address(this), 100 ether);
        plainToken.approve(address(escrowEngine), 100 ether);

        uint256 id = escrowEngine.createEscrow(address(this), recipient, address(plainToken), 100 ether);

        assertEq(plainToken.balanceOf(address(escrowEngine)), 100 ether);
        assertEq(escrowEngine.totalLockedByAsset(address(plainToken)), 100 ether);

        LibStorage.EscrowData memory data = escrowEngine.getEscrow(id);
        assertEq(data.amount, 100 ether, "recorded amount = 100");
        assertEq(data.asset, address(plainToken));
    }

    /// @notice Escrow release with a fee token can never exist (funding
    /// reverts), but the 5-arg overload must behave identically.
    function test_b_escrowFeeTokenRejectedWithReference() public {
        feeToken.mint(address(this), 100 ether);
        feeToken.approve(address(escrowEngine), 100 ether);

        vm.expectRevert(IEscrowEngine.EscrowFundingMismatch.selector);
        escrowEngine.createEscrow(
            address(this), recipient, address(feeToken), 100 ether, bytes32(uint256(0x1234))
        );
    }
}
