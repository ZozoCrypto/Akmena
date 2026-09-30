// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaCore} from "../../../src/core/AkmenaCore.sol";
import {AkmenaPolicyBoundary} from "../../../src/authorization/AkmenaPolicyBoundary.sol";
import {AkmenaExecutionAuthorization} from "../../../src/authorization/AkmenaExecutionAuthorization.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @notice Simple honest ERC20 for invariant testing.
contract InvariantMockToken is ERC20 {
    constructor() ERC20("Invariant", "INV") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function decimals() public pure override returns (uint8) {
        return 18;
    }
}

/// @notice Fuzzing adapter that records what it receives.
contract InvariantAdapter {
    uint256 public totalReceived;
    mapping(address => uint256) public receivedFrom;

    function execute(uint256 amount) external returns (bool) {
        totalReceived += amount;
        receivedFrom[msg.sender] += amount;
        return true;
    }
}

/// @notice Handler for Model D boundary invariants.
/// @dev Drives randomized settlement attempts and tracks ghost state for
/// invariant verification. All state changes are recorded so invariants can
/// check properties that span multiple transactions.
contract ModelDBoundaryHandler is Test {
    AkmenaCore public core;
    AkmenaPolicyBoundary public boundary;
    AkmenaExecutionAuthorization public auth;
    InvariantMockToken public token;
    InvariantAdapter public adapter;

    uint256 internal constant OPERATOR_KEY = 0x0E7A71;
    uint256 internal constant AGENT_KEY = 0xA6E171;

    address public operator;
    address public agent;

    // Ghost state for invariant checks.
    uint256 public successfulSettlements;
    uint256 public totalPulledFromOperator;
    uint256 public totalPushedToAdapter;
    uint256 public totalCharged;
    uint256 public nonceCounter;
    mapping(uint256 => bool) public nonceUsed;

    // Track operator balance changes to verify pull amounts.
    uint256 public operatorBalanceBefore;

    constructor() {
        operator = vm.addr(OPERATOR_KEY);
        agent = vm.addr(AGENT_KEY);

        core = new AkmenaCore();
        boundary = new AkmenaPolicyBoundary(address(core));
        auth = boundary.executionAuthorization();
        token = new InvariantMockToken();
        adapter = new InvariantAdapter();

        // Fund operator, approve boundary, set policy, admit token.
        token.mint(operator, 1_000_000 ether);
        vm.startPrank(operator);
        token.approve(address(boundary), type(uint256).max);
        boundary.setAgentAssetPolicy(agent, address(token), 100 ether, 1000 ether, false);
        vm.stopPrank();

        boundary.setStandardDebit(address(token), true);
        boundary.setEconomicAdapter(address(token), address(adapter), true);

        operatorBalanceBefore = token.balanceOf(operator);
    }

    /// @dev Attempt a randomized settlement. Records ghost state on success.
    function settle(uint256 amountSeed, uint256 nonceSeed) external {
        uint256 amount = bound(amountSeed, 0, 200 ether);
        nonceCounter++;
        uint256 nonce = nonceCounter + bound(nonceSeed, 0, 1000);

        // Skip if nonce already used (would revert with NonceAlreadyUsed).
        if (nonceUsed[nonce]) return;

        bytes memory payload = abi.encodeWithSelector(InvariantAdapter.execute.selector, amount);
        AkmenaExecutionAuthorization.ExecutionIntent memory intent =
            AkmenaExecutionAuthorization.ExecutionIntent({
                operator: operator,
                agent: agent,
                target: address(adapter),
                selector: InvariantAdapter.execute.selector,
                calldataHash: keccak256(payload),
                asset: address(token),
                amount: amount,
                value: 0,
                proofModuleKey: bytes32(0),
                proofId: 0,
                nonce: nonce,
                validAfter: 0,
                deadline: block.timestamp + 1 days
            });

        bytes32 digest = auth.hashIntent(intent);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(AGENT_KEY, digest);
        bytes memory sig = abi.encodePacked(r, s, v);

        uint256 opBalBefore = token.balanceOf(operator);
        uint256 adapterBalBefore = token.balanceOf(address(adapter));
        (,, uint256 spentBefore,,) = boundary.agentAssetPolicies(operator, agent, address(token));

        vm.prank(agent);
        try boundary.executeAuthorizedAgentCall(intent, payload, sig) {
            // Success: record ghost state.
            successfulSettlements++;
            nonceUsed[nonce] = true;

            uint256 pulled = opBalBefore - token.balanceOf(operator);
            uint256 pushed = token.balanceOf(address(adapter)) - adapterBalBefore;

            totalPulledFromOperator += pulled;
            totalPushedToAdapter += pushed;

            (,, uint256 spentAfter,,) = boundary.agentAssetPolicies(operator, agent, address(token));
            totalCharged += (spentAfter - spentBefore);
        } catch {
            // Revert is fine — invariants check that reverts are clean.
        }
    }

    // NOTE: No warpTime function — time warps reset the contract's daily
    // spent counter, which breaks cumulative ghost tracking in
    // `totalCharged`. Daily-reset behavior is covered by unit tests
    // (test_ReconfigureResetsCounters,
    // test_ResetBoundary_StrictlyGreaterThanOneDay). Invariants focus on
    // within-day properties.
}
