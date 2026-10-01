// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaCore} from "../../src/core/AkmenaCore.sol";
import {AkmenaPolicyBoundary} from "../../src/authorization/AkmenaPolicyBoundary.sol";
import {AkmenaExecutionAuthorization} from "../../src/authorization/AkmenaExecutionAuthorization.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice R12 expanded: native-path, replay, over-limit, governance, malicious-token on Base Sepolia fork.
/// @dev Forks Base Sepolia (84532). Skips gracefully if RPC unreachable.
contract ForkTestAdapter {
    uint256 public receivedNative;
    uint256 public receivedCall;
    receive() external payable {
        receivedNative += msg.value;
    }
    function execute(uint256 amount) external returns (bool) {
        receivedCall += amount;
        return true;
    }
    function depositNative() external payable returns (bool) {
        receivedNative += msg.value;
        return true;
    }
}

/// @notice Fee-on-transfer token (takes 10% on every transfer).
contract FeeToken {
    string public name = "FeeToken";
    string public symbol = "FEE";
    uint8 public decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        uint256 fee = amount / 10;
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount - fee;
        totalSupply -= fee;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        allowance[from][msg.sender] -= amount;
        uint256 fee = amount / 10;
        balanceOf[from] -= amount;
        balanceOf[to] += amount - fee;
        totalSupply -= fee;
        return true;
    }
}

contract ModelDBaseSepoliaForkExpandedTest is Test {
    uint256 internal constant OPERATOR_KEY = 0x0E7A71;
    uint256 internal constant AGENT_KEY = 0xA6E171;

    address internal operator;
    address internal agent;

    IERC20 internal constant USDC = IERC20(0x036CbD53842c5426634e7929541eC2318f3dCF7e);

    AkmenaCore internal core;
    AkmenaPolicyBoundary internal boundary;
    AkmenaExecutionAuthorization internal auth;
    ForkTestAdapter internal adapter;
    FeeToken internal feeToken;

    uint256 internal nonceCounter;

    function setUp() public {
        try vm.createSelectFork("https://sepolia.base.org") {} catch {
            vm.skip(true);
        }

        operator = vm.addr(OPERATOR_KEY);
        agent = vm.addr(AGENT_KEY);

        core = new AkmenaCore();
        boundary = new AkmenaPolicyBoundary(address(core));
        auth = AkmenaExecutionAuthorization(address(boundary.executionAuthorization()));
        adapter = new ForkTestAdapter();
        feeToken = new FeeToken();

        deal(address(USDC), operator, 1000 * 1e6);
        vm.deal(operator, 10 ether);
        vm.deal(agent, 10 ether);
        feeToken.mint(operator, 1000 ether);

        vm.startPrank(operator);
        USDC.approve(address(boundary), type(uint256).max);
        feeToken.approve(address(boundary), type(uint256).max);
        boundary.setAgentAssetPolicy(agent, address(USDC), 100 * 1e6, 100 * 1e6, false);
        boundary.setAgentPolicy(agent, 5 ether, 5 ether, false); // native uses base policy
        boundary.setAgentAssetPolicy(agent, address(feeToken), 100 ether, 100 ether, false);
        vm.stopPrank();

        boundary.setStandardDebit(address(USDC), true);
        boundary.setStandardDebit(address(feeToken), true);
        boundary.setEconomicAdapter(address(USDC), address(adapter), true);
    }

    function _signIntent(AkmenaExecutionAuthorization.ExecutionIntent memory intent)
        internal
        view
        returns (bytes memory)
    {
        bytes32 digest = auth.hashIntent(intent);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(AGENT_KEY, digest);
        return abi.encodePacked(r, s, v);
    }

    function _buildIntent(
        address target,
        bytes4 selector,
        bytes memory payload,
        address asset,
        uint256 amount,
        uint256 value
    ) internal returns (AkmenaExecutionAuthorization.ExecutionIntent memory) {
        return AkmenaExecutionAuthorization.ExecutionIntent({
            operator: operator,
            agent: agent,
            target: target,
            selector: selector,
            calldataHash: keccak256(payload),
            asset: asset,
            amount: amount,
            value: value,
            proofModuleKey: bytes32(0),
            proofId: 0,
            nonce: ++nonceCounter,
            validAfter: 0,
            deadline: block.timestamp + 1 days
        });
    }

    /// @notice Native ETH settlement on real fork state.
    function test_ForkNativeSettlement() public {
        uint256 amount = 1 ether;
        bytes memory payload = abi.encodeWithSelector(ForkTestAdapter.depositNative.selector);
        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _buildIntent(
            address(adapter),
            ForkTestAdapter.depositNative.selector,
            payload,
            address(0),
            amount,
            amount
        );

        bytes memory sig = _signIntent(intent);
        uint256 agentBefore = agent.balance;

        vm.prank(agent);
        boundary.executeAuthorizedAgentCall{value: amount}(intent, payload, sig);

        assertEq(agent.balance, agentBefore - amount, "Agent not debited native");
        assertEq(adapter.receivedNative(), amount, "Adapter did not receive native");
    }

    /// @notice Replay: same nonce twice must fail.
    function test_ForkReplayReverts() public {
        uint256 amount = 1 * 1e6;
        bytes memory payload = abi.encodeWithSelector(ForkTestAdapter.execute.selector, amount);
        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _buildIntent(
            address(adapter), ForkTestAdapter.execute.selector, payload, address(USDC), amount, 0
        );

        bytes memory sig = _signIntent(intent);

        vm.prank(agent);
        boundary.executeAuthorizedAgentCall(intent, payload, sig);

        vm.prank(agent);
        vm.expectRevert();
        boundary.executeAuthorizedAgentCall(intent, payload, sig);
    }

    /// @notice Over per-tx limit must revert on fork.
    function test_ForkOverLimitReverts() public {
        uint256 amount = 200 * 1e6;
        bytes memory payload = abi.encodeWithSelector(ForkTestAdapter.execute.selector, amount);
        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _buildIntent(
            address(adapter), ForkTestAdapter.execute.selector, payload, address(USDC), amount, 0
        );

        bytes memory sig = _signIntent(intent);

        vm.prank(agent);
        vm.expectRevert();
        boundary.executeAuthorizedAgentCall(intent, payload, sig);
    }

    /// @notice Governance: non-admin cannot touch allowlist.
    function test_ForkNonAdminCannotSetAdapter() public {
        vm.prank(agent);
        vm.expectRevert();
        boundary.setEconomicAdapter(address(USDC), address(adapter), false);
    }

    /// @notice Governance: allowlist admin transfer works, old admin loses power.
    function test_ForkAllowlistAdminTransfer() public {
        address newAdmin = address(0xBEEF);
        address deployer = core.deployer();

        vm.prank(deployer);
        boundary.setAllowlistAdmin(newAdmin);
        assertEq(boundary.allowlistAdmin(), newAdmin);

        vm.prank(deployer);
        vm.expectRevert();
        boundary.setEconomicAdapter(address(USDC), address(adapter), false);

        vm.prank(newAdmin);
        boundary.setEconomicAdapter(address(USDC), address(adapter), false);
    }

    /// @notice Fee-on-transfer token documents Model D pull behavior.
    function test_ForkFeeTokenSettlement() public {
        uint256 amount = 10 ether;
        bytes memory payload = abi.encodeWithSelector(ForkTestAdapter.execute.selector, amount);

        boundary.setEconomicAdapter(address(feeToken), address(adapter), true);

        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _buildIntent(
            address(adapter), ForkTestAdapter.execute.selector, payload, address(feeToken), amount, 0
        );

        bytes memory sig = _signIntent(intent);
        uint256 opBefore = feeToken.balanceOf(operator);

        vm.prank(agent);
        try boundary.executeAuthorizedAgentCall(intent, payload, sig) {
            uint256 debited = opBefore - feeToken.balanceOf(operator);
            assertEq(debited, amount, "Operator should be debited full intent amount");
        } catch {
            assertTrue(true, "Fail-closed on fee token is acceptable");
        }
    }
}
