// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {AkmenaPrivatePool, IWithdrawVerifier} from "../../src/privacy/v2/AkmenaPrivatePool.sol";
import {PoseidonT3} from "../../src/privacy/v2/PoseidonT3.sol";

/// @notice HAZARD DEMONSTRATION (passes = bypass is real).
///
/// Scenario (per external review):
///   agent under a 1 ETH daily spend limit
///     -> deposits 1 ETH into the pool (the pool enforces NOTHING about
///        where the funds came from or whether a limit was reserved)
///     -> withdraws 1 ETH to an arbitrary third-party address
///        (the pool enforces NOTHING about the recipient)
///
/// The standalone pool is INTENDED to be permissionless on both edges --
/// that is what makes the anonymity set grow. The policy enforcement MUST
/// therefore live in the integration layer (PolicyBoundary owning both
/// edges), not in the pool. This test pins the hazard so the future
/// integration acceptance test can invert it: once a policy-bound adapter
/// exists, `deposit` over the agent's limit and `withdraw` to an
/// unapproved recipient MUST revert there.
///
/// This is not a defect in the pool. It is the reason the pool must never
/// be wired into the agent execution path without the adapter.
contract PolicyBypassHazardTest is Test {
    AkmenaPrivatePool public pool;

    uint256 constant DENOM = 1 ether;
    uint256 constant AGENT_DAILY_LIMIT = 1 ether; // mock policy

    address agent = makeAddr("agent");
    address payable thirdParty = payable(makeAddr("thirdParty"));

    function setUp() public {
        // Permissive verifier: stands in for "valid ZK proof".
        PermissiveVerifier v = new PermissiveVerifier();
        pool = new AkmenaPrivatePool(IWithdrawVerifier(address(v)), DENOM);
        // Agent holds 100x its daily limit.
        vm.deal(agent, 100 ether);
    }

    function poseidon2(uint256 a, uint256 b) internal pure returns (bytes32) {
        return bytes32(PoseidonT3.hash([a, b]));
    }

    function test_HAZARD_OverLimitDepositThenThirdPartyWithdraw() public {
        uint256 depositAmount = DENOM; // == daily limit here; the point is
        // the pool never consults the limit at all.

        // Edge 1: deposit. No source check, no limit reservation.
        bytes32 commitment = poseidon2(111, 222);
        vm.prank(agent);
        pool.deposit{value: depositAmount}(commitment);
        assertEq(pool.anonymitySetSize(), 1);

        // Edge 2: withdraw to an ARBITRARY third party. No recipient policy.
        bytes32 root = pool.currentRoot();
        bytes32 nullifierHash = poseidon2(111, 0);
        uint256 before = thirdParty.balance;
        pool.withdraw(
            [uint256(1), uint256(2)],
            [[uint256(3), uint256(4)], [uint256(5), uint256(6)]],
            [uint256(7), uint256(8)],
            root, nullifierHash, thirdParty, payable(address(0)), 0
        );

        assertEq(thirdParty.balance - before, DENOM, "third party received funds");
        // The agent's 1 ETH "daily limit" was never consulted on either edge.
        // If this pool sat inside the agent execution path unwrapped, the
        // PolicyBoundary spend limit would be bypassable at will.
        console.log("HAZARD CONFIRMED: permissionless deposit + permissionless withdraw");
        console.log("Agent daily limit (mock):", AGENT_DAILY_LIMIT);
        console.log("Moved through pool without limit check:", depositAmount);
    }
}

contract PermissiveVerifier is IWithdrawVerifier {
    function verifyProof(uint256[2] calldata, uint256[2][2] calldata, uint256[2] calldata, uint256[5] calldata)
        external override returns (bool) { return true; }
}
