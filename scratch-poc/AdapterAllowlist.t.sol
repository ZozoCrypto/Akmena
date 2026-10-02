// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaCore} from "../src/core/AkmenaCore.sol";
import {AkmenaPolicyBoundary} from "../src/authorization/AkmenaPolicyBoundary.sol";
import {AkmenaExecutionAuthorization} from "../src/authorization/AkmenaExecutionAuthorization.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Minimal ERC20 for the PoC.
contract MockToken {
    string public name = "Mock";
    string public symbol = "MCK";
    uint8 public decimals = 18;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amt) external {
        balanceOf[to] += amt;
    }

    function transfer(address to, uint256 amt) external returns (bool) {
        require(balanceOf[msg.sender] >= amt, "insufficient");
        balanceOf[msg.sender] -= amt;
        balanceOf[to] += amt;
        return true;
    }

    function approve(address spender, uint256 amt) external returns (bool) {
        allowance[msg.sender][spender] = amt;
        return true;
    }

    function transferFrom(address from, address to, uint256 amt) external returns (bool) {
        require(balanceOf[from] >= amt, "insufficient");
        require(allowance[from][msg.sender] >= amt, "no allowance");
        allowance[from][msg.sender] -= amt;
        balanceOf[from] -= amt;
        balanceOf[to] += amt;
        return true;
    }
}

/// @notice Minimal economic adapter: pulls tokens from the caller (the boundary) to `to`.
contract PullAdapter {
    function pull(address token, address to, uint256 amt) external {
        IERC20(token).transferFrom(msg.sender, to, amt);
    }
}

contract AdapterAllowlist is Test {
    AkmenaCore internal core;
    AkmenaPolicyBoundary internal boundary;
    AkmenaExecutionAuthorization internal auth;
    MockToken internal token;

    uint256 internal constant AGENT_KEY = 0xA11CE;
    uint256 internal constant OPERATOR_KEY = 0xBEEF;
    address internal agent;
    address internal operator;
    address internal attacker = address(0xA77AC4);

    PullAdapter internal adapter;

    function setUp() public {
        core = new AkmenaCore(); // this test contract == core.deployer()
        boundary = new AkmenaPolicyBoundary(address(core));
        auth = boundary.executionAuthorization();
        token = new MockToken();
        agent = vm.addr(AGENT_KEY);
        operator = vm.addr(OPERATOR_KEY);
        adapter = new PullAdapter();
    }

    function _buildIntent(
        uint256 nonce,
        address target,
        bytes memory payload,
        uint256 amount
    ) internal view returns (AkmenaExecutionAuthorization.ExecutionIntent memory) {
        bytes4 selector;
        assembly {
            selector := mload(add(payload, 32))
        }
        return AkmenaExecutionAuthorization.ExecutionIntent({
            operator: operator,
            agent: agent,
            target: target,
            selector: selector,
            calldataHash: keccak256(payload),
            asset: address(token),
            amount: amount,
            value: 0,
            proofModuleKey: bytes32(0),
            proofId: 0,
            nonce: nonce,
            validAfter: block.timestamp,
            deadline: block.timestamp + 1 days
        });
    }

    function _sign(AkmenaExecutionAuthorization.ExecutionIntent memory intent)
        internal
        view
        returns (bytes memory)
    {
        bytes32 digest = auth.hashIntent(intent);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(AGENT_KEY, digest);
        return abi.encodePacked(r, s, v);
    }

    /// @notice Shared setup for the benign adapter flow.
    function _setupBenignFlow() internal {
        // Fund the boundary with 1000 tokens.
        token.mint(address(boundary), 1000e18);
        // Deployer allowlists the adapter for this token.
        boundary.setEconomicAdapter(address(token), address(adapter), true);
        // Simulate a prior legitimate boundary->adapter approval (done by test contract as boundary).
        vm.prank(address(boundary));
        token.approve(address(adapter), type(uint256).max);
        // Operator sets the ERC20 asset policy (requireEscrow=false).
        vm.prank(operator);
        boundary.setAgentAssetPolicy(agent, address(token), 500e18, 1000e18, false);
    }

    // ── (a) Non-deployer admin ─────────────────────────────────────────────
    function test_a_NonDeployerCannotAllowlist() public {
        vm.prank(attacker);
        vm.expectRevert(AkmenaPolicyBoundary.UnauthorizedAdapterAdmin.selector);
        boundary.setEconomicAdapter(address(token), address(adapter), true);

        // Confirm the mapping was NOT written.
        assertFalse(boundary.economicAdapters(address(token), address(adapter)));
    }

    // ── (b) Benign adapter flow ────────────────────────────────────────────
    function test_b_BenignAdapterFlow() public {
        _setupBenignFlow();

        address recipient = address(0xBEEF);
        uint256 amt = 100e18;
        bytes memory payload = abi.encodeCall(PullAdapter.pull, (address(token), recipient, amt));

        uint256 nonce = 1;
        AkmenaExecutionAuthorization.ExecutionIntent memory intent =
            _buildIntent(nonce, address(adapter), payload, amt);
        bytes memory sig = _sign(intent);

        uint256 boundaryBalBefore = token.balanceOf(address(boundary));
        vm.prank(agent);
        boundary.executeAuthorizedAgentCall(intent, payload, sig);

        assertEq(token.balanceOf(recipient), amt, "recipient must receive 100e18");
        assertEq(token.balanceOf(address(boundary)), boundaryBalBefore - amt, "boundary must lose 100e18");

        (,, uint256 totalSpentToday,,) = boundary.agentAssetPolicies(operator, agent, address(token));
        assertEq(totalSpentToday, amt, "totalSpentToday must equal measured spend");
    }

    // ── (c) Revocation: fresh nonce after revocation must revert ────────────
    function test_c_RevocationBlocksFreshExecution() public {
        _setupBenignFlow();

        address recipient = address(0xBEEF);
        uint256 amt = 100e18;
        bytes memory payload = abi.encodeCall(PullAdapter.pull, (address(token), recipient, amt));

        // Deployer revokes the adapter.
        boundary.setEconomicAdapter(address(token), address(adapter), false);
        assertFalse(boundary.economicAdapters(address(token), address(adapter)));

        // Agent retries with a FRESH nonce + signature.
        AkmenaExecutionAuthorization.ExecutionIntent memory intent =
            _buildIntent(2, address(adapter), payload, amt);
        bytes memory sig = _sign(intent);

        vm.prank(agent);
        vm.expectRevert(AkmenaPolicyBoundary.EconomicAdapterNotAllowed.selector);
        boundary.executeAuthorizedAgentCall(intent, payload, sig);

        // State must be unchanged: no tokens moved.
        assertEq(token.balanceOf(recipient), 0);
        assertEq(token.balanceOf(address(boundary)), 1000e18);
    }

    // ── (c2) Timing: sign BEFORE revocation, execute AFTER → must revert ────
    function test_c2_UseAfterRevokeSignedBeforeRevocation() public {
        _setupBenignFlow();

        address recipient = address(0xBEEF);
        uint256 amt = 100e18;
        bytes memory payload = abi.encodeCall(PullAdapter.pull, (address(token), recipient, amt));

        // Sign while the adapter is still allowlisted.
        AkmenaExecutionAuthorization.ExecutionIntent memory intent =
            _buildIntent(3, address(adapter), payload, amt);
        bytes memory sig = _sign(intent);

        // Deployer revokes AFTER signing, BEFORE execution.
        boundary.setEconomicAdapter(address(token), address(adapter), false);

        // Execution must revert: allowlist is read at execution time.
        vm.prank(agent);
        vm.expectRevert(AkmenaPolicyBoundary.EconomicAdapterNotAllowed.selector);
        boundary.executeAuthorizedAgentCall(intent, payload, sig);

        assertEq(token.balanceOf(recipient), 0, "no tokens must move on revoked adapter");
        assertEq(token.balanceOf(address(boundary)), 1000e18);
    }

    // ── (c3) Reverse: sign BEFORE allowlist, execute AFTER → must succeed ───
    function test_c3_AllowlistedAfterSigningSucceeds() public {
        // Setup WITHOUT allowlisting the adapter (boundary funded, approval, policy set).
        token.mint(address(boundary), 1000e18);
        vm.prank(address(boundary));
        token.approve(address(adapter), type(uint256).max);
        vm.prank(operator);
        boundary.setAgentAssetPolicy(agent, address(token), 500e18, 1000e18, false);
        assertFalse(boundary.economicAdapters(address(token), address(adapter)));

        address recipient = address(0xBEEF);
        uint256 amt = 100e18;
        bytes memory payload = abi.encodeCall(PullAdapter.pull, (address(token), recipient, amt));

        // Sign while the adapter is NOT allowlisted.
        AkmenaExecutionAuthorization.ExecutionIntent memory intent =
            _buildIntent(4, address(adapter), payload, amt);
        bytes memory sig = _sign(intent);

        // Allowlist AFTER signing.
        boundary.setEconomicAdapter(address(token), address(adapter), true);

        vm.prank(agent);
        boundary.executeAuthorizedAgentCall(intent, payload, sig);

        assertEq(token.balanceOf(recipient), amt, "must succeed when allowlisted at execution time");
    }

    // ── (d) Input validation on setEconomicAdapter ─────────────────────────
    function test_d_InvalidAdapterAndAsset() public {
        // adapter == address(0)
        vm.expectRevert(AkmenaPolicyBoundary.InvalidAdapter.selector);
        boundary.setEconomicAdapter(address(token), address(0), true);

        // adapter is an EOA (no code)
        vm.expectRevert(AkmenaPolicyBoundary.InvalidAdapter.selector);
        boundary.setEconomicAdapter(address(token), address(0xBEEF), true);

        // asset == address(0)
        vm.expectRevert(AkmenaPolicyBoundary.InvalidAsset.selector);
        boundary.setEconomicAdapter(address(0), address(adapter), true);
    }

    // ── (d2) Deployer (this test contract) can write the allowlist ─────────
    function test_d2_DeployerCanAllowlist() public {
        assertEq(core.deployer(), address(this));
        boundary.setEconomicAdapter(address(token), address(adapter), true);
        assertTrue(boundary.economicAdapters(address(token), address(adapter)));
    }
}
