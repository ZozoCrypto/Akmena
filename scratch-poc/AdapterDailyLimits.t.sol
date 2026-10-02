// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import {AkmenaCore} from "../src/core/AkmenaCore.sol";
import {AkmenaPolicyBoundary} from "../src/authorization/AkmenaPolicyBoundary.sol";
import {AkmenaExecutionAuthorization} from "../src/authorization/AkmenaExecutionAuthorization.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Minimal ERC20 mock for PoC (mint is permissionless, test-only).
contract MockToken {
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(string memory n, string memory s) {
        name = n;
        symbol = s;
    }

    function mint(address to, uint256 amt) external {
        balanceOf[to] += amt;
        totalSupply += amt;
    }

    function approve(address sp, uint256 amt) external returns (bool) {
        allowance[msg.sender][sp] = amt;
        return true;
    }

    function transfer(address to, uint256 amt) external returns (bool) {
        balanceOf[msg.sender] -= amt;
        balanceOf[to] += amt;
        return true;
    }

    function transferFrom(address from, address to, uint256 amt) external returns (bool) {
        uint256 a = allowance[from][msg.sender];
        if (a != type(uint256).max) {
            allowance[from][msg.sender] = a - amt;
        }
        balanceOf[from] -= amt;
        balanceOf[to] += amt;
        return true;
    }
}

/// @notice Benign economic adapter: pulls `amt` of `token` out of the caller
/// (the PolicyBoundary) to `to`. Allowlisted per-asset by the core deployer.
/// `payable` so value-carrying native intents can target it without reverting.
contract PullAdapter {
    function pull(address token, address to, uint256 amt) external payable {
        IERC20(token).transferFrom(msg.sender, to, amt);
    }

    receive() external payable {}
}

/// @notice Scenario 3: ERC20 daily limits (measured-spend accounting) +
/// per-asset policy isolation on AkmenaPolicyBoundary @ 8deead98.
contract AdapterDailyLimits is Test {
    uint256 constant AGENT_KEY = 0xA11CEB0B;
    address agent;
    address operator;
    address recipient;

    AkmenaCore core;
    AkmenaPolicyBoundary boundary;
    AkmenaExecutionAuthorization auth;
    PullAdapter adapter;
    MockToken tokenA;
    MockToken tokenB;

    function setUp() public {
        agent = vm.addr(AGENT_KEY);
        operator = makeAddr("operator");
        recipient = makeAddr("recipient");

        core = new AkmenaCore(); // this test contract == core.deployer()
        boundary = new AkmenaPolicyBoundary(address(core));
        auth = boundary.executionAuthorization();

        adapter = new PullAdapter();
        tokenA = new MockToken("TokenA", "TKA");
        tokenB = new MockToken("TokenB", "TKB");

        // Allowlist the adapter for BOTH assets (deployer-only admin fn).
        boundary.setEconomicAdapter(address(tokenA), address(adapter), true);
        boundary.setEconomicAdapter(address(tokenB), address(adapter), true);

        // Boundary pre-approves the adapter so pull() can move custody.
        vm.prank(address(boundary));
        tokenA.approve(address(adapter), type(uint256).max);
        vm.prank(address(boundary));
        tokenB.approve(address(adapter), type(uint256).max);
    }

    // ---------- helpers ----------

    function _fundBoundary(MockToken t, uint256 amt) internal {
        t.mint(address(this), amt);
        t.transfer(address(boundary), amt);
    }

    function _selector(bytes memory payload) internal pure returns (bytes4 sel) {
        assembly {
            sel := mload(add(payload, 32))
        }
    }

    function _intent(address asset, uint256 amount, uint256 value, bytes memory payload, uint256 nonce)
        internal
        view
        returns (AkmenaExecutionAuthorization.ExecutionIntent memory i)
    {
        i = AkmenaExecutionAuthorization.ExecutionIntent({
            operator: operator,
            agent: agent,
            target: address(adapter),
            selector: _selector(payload),
            calldataHash: keccak256(payload),
            asset: asset,
            amount: amount,
            value: value,
            proofModuleKey: bytes32(0),
            proofId: 0,
            nonce: nonce,
            validAfter: 0,
            deadline: block.timestamp + 7 days
        });
    }

    function _sign(AkmenaExecutionAuthorization.ExecutionIntent memory i) internal view returns (bytes memory sig) {
        bytes32 digest = auth.hashIntent(i);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(AGENT_KEY, digest);
        sig = abi.encodePacked(r, s, v);
    }

    function _exec(AkmenaExecutionAuthorization.ExecutionIntent memory i, bytes memory payload, bytes memory sig)
        internal
        returns (bytes memory)
    {
        vm.prank(agent);
        return boundary.executeAuthorizedAgentCall(i, payload, sig);
    }

    function _spentToday(address asset) internal view returns (uint256) {
        (, , uint256 spent,,) = boundary.agentAssetPolicies(operator, agent, asset);
        return spent;
    }

    // ---------- (a) ERC20 daily limit on measured spend ----------

    function test_a_dailyLimitOnMeasuredSpend() public {
        vm.prank(operator);
        boundary.setAgentAssetPolicy(agent, address(tokenA), 1000e18, 150e18, false);
        _fundBoundary(tokenA, 1000e18);

        // Intent 1: pull 100e18 -> measured spend 100e18, within daily 150e18.
        bytes memory p1 = abi.encodeCall(PullAdapter.pull, (address(tokenA), recipient, 100e18));
        AkmenaExecutionAuthorization.ExecutionIntent memory i1 = _intent(address(tokenA), 100e18, 0, p1, 1);
        _exec(i1, p1, _sign(i1));

        uint256 spent1 = _spentToday(address(tokenA));
        assertEq(spent1, 100e18, "totalSpentToday must equal MEASURED spend (100e18)");

        // Intent 2: another 100e18 -> 100e18 > 150e18 - 100e18 = 50e18 -> PolicyExceeded.
        bytes memory p2 = abi.encodeCall(PullAdapter.pull, (address(tokenA), recipient, 100e18));
        AkmenaExecutionAuthorization.ExecutionIntent memory i2 = _intent(address(tokenA), 100e18, 0, p2, 2);
        bytes memory s2 = _sign(i2); // sign BEFORE prank: _sign makes an external call
        vm.prank(agent);
        vm.expectRevert(AkmenaPolicyBoundary.PolicyExceeded.selector);
        boundary.executeAuthorizedAgentCall(i2, p2, s2);

        // Declared ceiling: amount=60e18 declared but payload pulls 100e18
        // -> EconomicSpendExceedsIntent (declared is a ceiling on measured).
        bytes memory p3 = abi.encodeCall(PullAdapter.pull, (address(tokenA), recipient, 100e18));
        AkmenaExecutionAuthorization.ExecutionIntent memory i3 = _intent(address(tokenA), 60e18, 0, p3, 3);
        bytes memory s3 = _sign(i3); // sign BEFORE prank
        vm.prank(agent);
        vm.expectRevert(AkmenaPolicyBoundary.EconomicSpendExceedsIntent.selector);
        boundary.executeAuthorizedAgentCall(i3, p3, s3);
    }

    // ---------- (b) per-asset isolation ground truth ----------

    function test_b_perAssetIsolation() public {
        vm.prank(operator);
        boundary.setAgentAssetPolicy(agent, address(tokenA), 1000e18, 100e18, false);
        vm.prank(operator);
        boundary.setAgentAssetPolicy(agent, address(tokenB), 1000e18, 100e18, false);
        _fundBoundary(tokenA, 500e18);
        _fundBoundary(tokenB, 500e18);

        // Fill tokenA's daily budget completely.
        bytes memory pa = abi.encodeCall(PullAdapter.pull, (address(tokenA), recipient, 100e18));
        AkmenaExecutionAuthorization.ExecutionIntent memory ia = _intent(address(tokenA), 100e18, 0, pa, 10);
        _exec(ia, pa, _sign(ia));

        // tokenA is now exhausted: a further 1 wei of A must revert PolicyExceeded.
        bytes memory pa2 = abi.encodeCall(PullAdapter.pull, (address(tokenA), recipient, 1));
        AkmenaExecutionAuthorization.ExecutionIntent memory ia2 = _intent(address(tokenA), 1, 0, pa2, 11);
        bytes memory sa2 = _sign(ia2); // sign BEFORE prank
        vm.prank(agent);
        vm.expectRevert(AkmenaPolicyBoundary.PolicyExceeded.selector);
        boundary.executeAuthorizedAgentCall(ia2, pa2, sa2);

        // tokenB spend of a full 100e18: succeeds iff budgets are per-asset isolated.
        bytes memory pb = abi.encodeCall(PullAdapter.pull, (address(tokenB), recipient, 100e18));
        AkmenaExecutionAuthorization.ExecutionIntent memory ib = _intent(address(tokenB), 100e18, 0, pb, 12);
        _exec(ib, pb, _sign(ib)); // reverts here => budgets are SHARED, not isolated

        assertEq(_spentToday(address(tokenA)), 100e18, "tokenA recorded 100e18");
        assertEq(_spentToday(address(tokenB)), 100e18, "tokenB recorded 100e18");

        // tokenB's own budget is also enforced: another 1 wei of B reverts.
        bytes memory pb2 = abi.encodeCall(PullAdapter.pull, (address(tokenB), recipient, 1));
        AkmenaExecutionAuthorization.ExecutionIntent memory ib2 = _intent(address(tokenB), 1, 0, pb2, 13);
        bytes memory sb2 = _sign(ib2); // sign BEFORE prank
        vm.prank(agent);
        vm.expectRevert(AkmenaPolicyBoundary.PolicyExceeded.selector);
        boundary.executeAuthorizedAgentCall(ib2, pb2, sb2);

        // ERC20 spending must NOT touch the native (agentPolicies) budget.
        (uint256 nMax, uint256 nDaily, uint256 nSpent,,) = boundary.agentPolicies(operator, agent);
        assertEq(nMax, 0, "native maxSpendPerTransaction untouched");
        assertEq(nDaily, 0, "native dailyLimit untouched");
        assertEq(nSpent, 0, "native totalSpentToday untouched by ERC20 spend");
    }

    // ---------- (c) rolling 24h reset ----------

    function test_c_dailyResetBoundary() public {
        vm.prank(operator);
        boundary.setAgentAssetPolicy(agent, address(tokenA), 1000e18, 100e18, false);
        _fundBoundary(tokenA, 500e18);

        bytes memory p1 = abi.encodeCall(PullAdapter.pull, (address(tokenA), recipient, 100e18));
        AkmenaExecutionAuthorization.ExecutionIntent memory i1 = _intent(address(tokenA), 100e18, 0, p1, 20);
        _exec(i1, p1, _sign(i1));
        assertEq(_spentToday(address(tokenA)), 100e18, "daily filled before warp");

        // Cross the rolling 24h boundary: reset must trigger on next execution.
        vm.warp(block.timestamp + 1 days + 1);

        bytes memory p2 = abi.encodeCall(PullAdapter.pull, (address(tokenA), recipient, 100e18));
        AkmenaExecutionAuthorization.ExecutionIntent memory i2 = _intent(address(tokenA), 100e18, 0, p2, 21);
        _exec(i2, p2, _sign(i2)); // reverts here => reset did NOT happen

        assertEq(_spentToday(address(tokenA)), 100e18, "totalSpentToday reset then accrued 100e18 again");
    }

    // ---------- (d) native / ERC20 cross-contamination ----------

    function test_d_nativeAndErc20BudgetsSeparate() public {
        vm.prank(operator);
        boundary.setAgentAssetPolicy(agent, address(tokenA), 1000e18, 100e18, false);
        _fundBoundary(tokenA, 500e18);
        vm.prank(operator);
        boundary.setAgentPolicy(agent, 10 ether, 1 ether, false);
        vm.deal(agent, 10 ether);

        // Fill the NATIVE daily with a value-carrying intent (amount == value).
        // Payload is a zero-token pull so the ERC20 path is untouched.
        bytes memory pn = abi.encodeCall(PullAdapter.pull, (address(tokenA), recipient, 0));
        AkmenaExecutionAuthorization.ExecutionIntent memory inn = _intent(address(0), 1 ether, 1 ether, pn, 30);
        bytes memory sn = _sign(inn); // sign BEFORE prank
        vm.prank(agent);
        boundary.executeAuthorizedAgentCall{value: 1 ether}(inn, pn, sn);

        (,, uint256 nSpent,,) = boundary.agentPolicies(operator, agent);
        assertEq(nSpent, 1 ether, "native daily filled with 1 ether");

        // ERC20 spend must be unaffected by the exhausted native budget.
        bytes memory pe = abi.encodeCall(PullAdapter.pull, (address(tokenA), recipient, 100e18));
        AkmenaExecutionAuthorization.ExecutionIntent memory ie = _intent(address(tokenA), 100e18, 0, pe, 31);
        _exec(ie, pe, _sign(ie)); // reverts here => cross-contamination

        assertEq(_spentToday(address(tokenA)), 100e18, "ERC20 budget independent of native");
    }
}
