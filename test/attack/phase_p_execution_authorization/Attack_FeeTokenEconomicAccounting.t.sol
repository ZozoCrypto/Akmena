// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaCore} from "../../../src/core/AkmenaCore.sol";
import {AkmenaPolicyBoundary} from "../../../src/authorization/AkmenaPolicyBoundary.sol";
import {AkmenaExecutionAuthorization} from "../../../src/authorization/AkmenaExecutionAuthorization.sol";
import {EscrowEngine} from "../../../src/economics/EscrowEngine.sol";
import {IEscrowEngine} from "../../../src/economics/IEscrowEngine.sol";
import {LibStorage} from "../../../src/storage/LibStorage.sol";
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

/// @notice Minimal push-style adapter: the boundary pushes intent.amount
/// here before invoking the payload. The adapter cannot pull; no pull
/// allowance from the boundary exists.
contract PushAdapter {
    function receiveFunds() external {
        // Intentionally no-op: settlement is the push itself.
    }
}

/// @notice Fee-on-transfer token vs Model D exact-amount settlement.
///
/// Under Model D there is no balance-delta measurement to distort:
/// settlement pulls exactly intent.amount from the operator and pushes
/// exactly intent.amount to the allowlisted adapter. A fee-on-transfer
/// token therefore FAILS CLOSED whenever the fee leaves the boundary
/// underfunded for the push (the whole transaction — pull, push, charge,
/// nonce — rolls back atomically). Fee tokens are excluded from
/// Standard-Debit admission; these tests pin the raw contract behavior:
/// (a) boundary execution fails closed; (b) escrow funding still rejects
/// fee tokens while plain tokens fund cleanly; (c) fee-to-boundary and
/// fee-to-third-party edges.
contract Attack_FeeTokenEconomicAccounting is Test {
    AkmenaCore internal core;
    AkmenaPolicyBoundary internal boundary;
    AkmenaExecutionAuthorization internal auth;
    EscrowEngine internal escrowEngine;
    FeeToken internal feeToken;
    PlainToken internal plainToken;
    PushAdapter internal adapter;

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
        adapter = new PushAdapter();

        escrowEngine = new EscrowEngine(address(plainToken));

        // Operator policy for the fee token: max 1000/tx, 10000/day.
        boundary.setAgentAssetPolicy(agent, address(feeToken), 1000 ether, 10000 ether, false);
        // Allowlist the adapter for the fee token (test contract is deployer).
        boundary.setEconomicAdapter(address(feeToken), address(adapter), true);
        boundary.setStandardDebit(address(feeToken), true);

        // Model D: the operator (this test contract) funds itself and
        // approves the boundary. The boundary never holds pooled funds and
        // never grants the adapter a pull allowance.
        feeToken.mint(address(this), 1000 ether);
        feeToken.approve(address(boundary), type(uint256).max);
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

    /*//////////////////////////////////////////////////////////////
                              (a) BOUNDARY
    //////////////////////////////////////////////////////////////*/

    /// @notice Model D: a fee-on-transfer token FAILS CLOSED. The pull
    /// takes 100 from the operator but only 90 arrives at the boundary
    /// (10% fee to the collector), so the exact-amount push of 100
    /// reverts. The whole transaction — pull, push, charge, nonce —
    /// rolls back atomically: nothing is spent, nothing is recorded.
    function test_a_feeTokenFailsClosedAtomically() public {
        bytes memory payload = abi.encodeWithSelector(PushAdapter.receiveFunds.selector);
        AkmenaExecutionAuthorization.ExecutionIntent memory intent =
            _intent(address(adapter), payload, address(feeToken), 100 ether);
        bytes memory sig = _sign(intent); // sign BEFORE expectRevert: hashIntent is an external call

        vm.prank(agent);
        vm.expectRevert(); // ERC20InsufficientBalance on the underfunded push
        boundary.executeAuthorizedAgentCall(intent, payload, sig);

        // Atomic rollback: the operator keeps everything, nobody received anything.
        assertEq(feeToken.balanceOf(address(this)), 1000 ether, "operator balance unchanged");
        assertEq(feeToken.balanceOf(address(boundary)), 0, "boundary received nothing");
        assertEq(feeToken.balanceOf(address(adapter)), 0, "adapter received nothing");
        assertEq(feeToken.balanceOf(feeCollector), 0, "collector received nothing");
        assertEq(_totalSpent(address(feeToken)), 0, "no spend recorded");
        assertFalse(auth.usedNonces(agent, intent.nonce), "nonce not consumed");
    }

    /// @notice Model D: even a smaller intent cannot slip a fee token
    /// through. Intent 90: the pull delivers 81 after the fee, the exact
    /// push of 90 reverts, and everything rolls back atomically.
    function test_a_smallerIntentStillFailsClosed() public {
        bytes memory payload = abi.encodeWithSelector(PushAdapter.receiveFunds.selector);
        AkmenaExecutionAuthorization.ExecutionIntent memory intent =
            _intent(address(adapter), payload, address(feeToken), 90 ether);
        bytes memory sig = _sign(intent); // sign BEFORE expectRevert: hashIntent is an external call

        vm.prank(agent);
        vm.expectRevert();
        boundary.executeAuthorizedAgentCall(intent, payload, sig);

        assertEq(feeToken.balanceOf(address(this)), 1000 ether, "operator balance unchanged");
        assertEq(feeToken.balanceOf(address(boundary)), 0, "boundary received nothing");
        assertEq(feeToken.balanceOf(address(adapter)), 0, "adapter received nothing");
        assertEq(_totalSpent(address(feeToken)), 0, "no spend recorded");
        assertFalse(auth.usedNonces(agent, intent.nonce), "nonce not consumed");
    }

    /// @notice Model D: repeated fee-token attempts consume no budget.
    /// Both executions revert; the daily total stays zero and the
    /// operator balance is untouched.
    function test_a_repeatedFeeTokenAttemptsConsumeNoBudget() public {
        for (uint256 i = 0; i < 2; i++) {
            bytes memory payload = abi.encodeWithSelector(PushAdapter.receiveFunds.selector);
            AkmenaExecutionAuthorization.ExecutionIntent memory intent =
                _intent(address(adapter), payload, address(feeToken), 100 ether);
            bytes memory sig = _sign(intent);

            vm.prank(agent);
            vm.expectRevert();
            boundary.executeAuthorizedAgentCall(intent, payload, sig);
        }

        assertEq(feeToken.balanceOf(address(this)), 1000 ether, "operator balance unchanged");
        assertEq(_totalSpent(address(feeToken)), 0, "no budget consumed");
    }

    /// @notice Edge (c1): fee routed to the BOUNDARY itself. This is the
    /// one fee-token edge that does NOT fail closed: the pull delivers
    /// the full 100 to the boundary (90 + 10 fee-to-self), so the exact
    /// push of 100 is funded and execution succeeds. The economics stay
    /// exact — the operator authorized 100 and 100 left the operator, so
    /// the charge is exactly 100 — but the push itself takes a 10% fee,
    /// so the adapter nets 90 and the 10 fee is stranded in the boundary
    /// (no sweep by design). It is never misaccounted: the stranded fee
    /// cannot reduce the charge or be extracted without a signed intent.
    /// Fee tokens remain excluded from Standard-Debit admission; this
    /// pins the raw contract behavior for the edge.
    function test_c_feeToBoundarySucceedsWithFeeStranded() public {
        feeToken.setFeeCollector(address(boundary));

        bytes memory payload = abi.encodeWithSelector(PushAdapter.receiveFunds.selector);
        AkmenaExecutionAuthorization.ExecutionIntent memory intent =
            _intent(address(adapter), payload, address(feeToken), 100 ether);
        bytes memory sig = _sign(intent);

        vm.prank(agent);
        boundary.executeAuthorizedAgentCall(intent, payload, sig);

        assertEq(feeToken.balanceOf(address(this)), 900 ether, "operator debited exactly 100");
        assertEq(_totalSpent(address(feeToken)), 100 ether, "charge exactly 100");
        assertEq(feeToken.balanceOf(address(adapter)), 90 ether, "adapter nets 90 after push fee");
        assertEq(feeToken.balanceOf(address(boundary)), 10 ether, "fee stranded in boundary");
    }

    /// @notice Edge (c2): fee routed to a third party fails closed. The
    /// pull delivers 90 to the boundary and 10 to the third party; the
    /// exact push of 100 reverts and the whole transaction rolls back —
    /// the third party keeps nothing.
    function test_c_feeToThirdPartyFailsClosed() public {
        address thirdParty = address(0x7A7A);
        feeToken.setFeeCollector(thirdParty);

        bytes memory payload = abi.encodeWithSelector(PushAdapter.receiveFunds.selector);
        AkmenaExecutionAuthorization.ExecutionIntent memory intent =
            _intent(address(adapter), payload, address(feeToken), 100 ether);
        bytes memory sig = _sign(intent);

        vm.prank(agent);
        vm.expectRevert();
        boundary.executeAuthorizedAgentCall(intent, payload, sig);

        assertEq(feeToken.balanceOf(address(this)), 1000 ether, "operator balance unchanged");
        assertEq(feeToken.balanceOf(thirdParty), 0, "third party received nothing");
        assertEq(feeToken.balanceOf(address(adapter)), 0, "adapter received nothing");
        assertEq(feeToken.balanceOf(address(boundary)), 0, "boundary received nothing");
        assertEq(_totalSpent(address(feeToken)), 0, "no spend recorded");
        assertFalse(auth.usedNonces(agent, intent.nonce), "nonce not consumed");
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
