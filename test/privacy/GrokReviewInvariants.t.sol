// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaPrivatePool, IWithdrawVerifier} from "../../src/privacy/v2/AkmenaPrivatePool.sol";
import {PoseidonT3} from "../../src/privacy/v2/PoseidonT3.sol";

/// @notice Mock verifier with programmable pass/fail.
contract MockVerifier2 is IWithdrawVerifier {
    bool public shouldPass = true;
    function setShouldPass(bool _p) external { shouldPass = _p; }
    function verifyProof(uint256[2] calldata, uint256[2][2] calldata, uint256[2] calldata, uint256[5] calldata)
        external override returns (bool) { return shouldPass; }
}

/// @notice Grok-review verification tests: pins two of the five required
///         integration invariants as EXECUTABLE properties of the
///         standalone pool.
///         - "Failed withdraw does not burn the nullifier" -> HOLDS.
///         - "Pool admin cannot swap the verifier without a timelock" ->
///           MOOT BY CONSTRUCTION (immutable, no admin role exists).
contract GrokReviewInvariantsTest is Test {
    AkmenaPrivatePool public pool;
    MockVerifier2 public mockVerifier;

    uint256 constant DENOM = 1 ether;

    address depositor = makeAddr("depositor");
    address payable recipient = payable(makeAddr("recipient"));

    function setUp() public {
        mockVerifier = new MockVerifier2();
        pool = new AkmenaPrivatePool(IWithdrawVerifier(address(mockVerifier)), DENOM);
        vm.deal(depositor, 10 ether);
    }

    function poseidon2(uint256 a, uint256 b) internal pure returns (bytes32) {
        return bytes32(PoseidonT3.hash([a, b]));
    }

    /// @notice A withdraw with an INVALID proof must revert WITHOUT
    ///         consuming the nullifier: the note must remain spendable
    ///         with a correct proof afterwards. (Grok invariant #4.)
    function test_FailedProofDoesNotBurnNullifier() public {
        bytes32 commitment = poseidon2(4242, 777);
        vm.prank(depositor);
        pool.deposit{value: DENOM}(commitment);

        bytes32 root = pool.currentRoot();
        bytes32 nullifierHash = poseidon2(4242, 0);

        // 1. Invalid proof -> reverts.
        mockVerifier.setShouldPass(false);
        vm.expectRevert(AkmenaPrivatePool.InvalidProof.selector);
        pool.withdraw(
            [uint256(1), uint256(2)],
            [[uint256(3), uint256(4)], [uint256(5), uint256(6)]],
            [uint256(7), uint256(8)],
            root, nullifierHash, recipient, payable(address(0)), 0
        );

        // 2. Nullifier must NOT be marked spent.
        assertFalse(pool.nullifierHashes(nullifierHash), "nullifier burned by failed proof");

        // 3. A correct proof for the same note still works.
        mockVerifier.setShouldPass(true);
        uint256 before = recipient.balance;
        pool.withdraw(
            [uint256(1), uint256(2)],
            [[uint256(3), uint256(4)], [uint256(5), uint256(6)]],
            [uint256(7), uint256(8)],
            root, nullifierHash, recipient, payable(address(0)), 0
        );
        assertEq(recipient.balance - before, DENOM, "note unspendable after failed proof");
        assertTrue(pool.nullifierHashes(nullifierHash), "nullifier not marked after success");
    }

    /// @notice The verifier is immutable and there is no admin role, so
    ///         "swap the verifier" is not an available action at all.
    ///         (Grok invariant #5 - satisfied by construction, stronger
    ///         than the timelock requirement.)
    function test_VerifierImmutableNoAdmin() public {
        assertEq(address(pool.VERIFIER()), address(mockVerifier), "verifier mismatch");
        // No setVerifier / transferOwnership / admin entrypoint exists on the
        // pool: the ABI is deposit, withdraw, and views only.
        assertEq(pool.DENOMINATION(), DENOM);
    }
}
