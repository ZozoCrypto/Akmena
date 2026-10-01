// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {AkmenaPrivatePool, IWithdrawVerifier} from "../../src/privacy/v2/AkmenaPrivatePool.sol";
import {PoseidonT3} from "../../src/privacy/v2/PoseidonT3.sol";

/// @notice Mock verifier for pool-logic testing. The real Groth16 verifier
///         (snarkjs-generated) replaces this once the trusted setup completes.
///         Pool logic (tree, nullifiers, payments) is verifier-agnostic.
contract MockVerifier is IWithdrawVerifier {
    bool public shouldPass = true;

    event ProofChecked(uint256[5] pubSignals);

    function setShouldPass(bool _pass) external {
        shouldPass = _pass;
    }

    function verifyProof(
        uint256[2] calldata,
        uint256[2][2] calldata,
        uint256[2] calldata,
        uint256[5] calldata _pubSignals
    ) external override returns (bool) {
        emit ProofChecked(_pubSignals);
        return shouldPass;
    }
}

contract AkmenaPrivatePoolTest is Test {
    AkmenaPrivatePool public pool;
    MockVerifier public mockVerifier;

    uint256 constant DENOM = 1 ether;
    uint256 constant TREE_DEPTH = 20;

    address depositor = makeAddr("depositor");
    address payable recipient = payable(makeAddr("recipient"));
    address payable relayer = payable(makeAddr("relayer"));

    function setUp() public {
        mockVerifier = new MockVerifier();
        pool = new AkmenaPrivatePool(IWithdrawVerifier(address(mockVerifier)), DENOM);
        vm.deal(depositor, 10 ether);
    }

    // --- Helpers (mirror contract tree off-chain) ---

    function poseidon2(uint256 a, uint256 b) internal pure returns (bytes32) {
        return bytes32(PoseidonT3.hash([a, b]));
    }

    // --- Tests ---

    function test_DepositEmitsAndIncrementsLeaf() public {
        bytes32 commitment = poseidon2(12345, 67890);

        vm.expectEmit(true, true, false, false);
        emit AkmenaPrivatePool.Deposit(commitment, 0, block.timestamp);
        vm.prank(depositor);
        pool.deposit{value: DENOM}(commitment);

        assertEq(pool.nextLeafIndex(), 1);
        assertEq(pool.anonymitySetSize(), 1);
        assertEq(address(pool).balance, DENOM);
    }

    function test_DepositWrongAmountReverts() public {
        bytes32 commitment = poseidon2(1, 2);
        vm.prank(depositor);
        vm.expectRevert(AkmenaPrivatePool.IncorrectDenomination.selector);
        pool.deposit{value: DENOM - 1}(commitment);
    }

    function test_DepositZeroReverts() public {
        bytes32 commitment = poseidon2(1, 2);
        vm.prank(depositor);
        vm.expectRevert(AkmenaPrivatePool.IncorrectDenomination.selector);
        pool.deposit{value: 0}(commitment);
    }

    function test_WithdrawHappyPath() public {
        // Deposit first
        bytes32 commitment = poseidon2(12345, 67890);
        vm.prank(depositor);
        pool.deposit{value: DENOM}(commitment);

        bytes32 root = pool.currentRoot();
        bytes32 nullifierHash = poseidon2(12345, 0);
        uint256 fee = 0.01 ether;

        uint256 recipientBefore = recipient.balance;
        uint256 relayerBefore = relayer.balance;

        pool.withdraw(
            [uint256(1), uint256(2)],
            [[uint256(3), uint256(4)], [uint256(5), uint256(6)]],
            [uint256(7), uint256(8)],
            root,
            nullifierHash,
            recipient,
            relayer,
            fee
        );

        assertEq(recipient.balance - recipientBefore, DENOM - fee, "recipient amount");
        assertEq(relayer.balance - relayerBefore, fee, "relayer fee");
        assertTrue(pool.nullifierHashes(nullifierHash), "nullifier marked spent");
        assertEq(address(pool).balance, 0, "pool drained exactly");
    }

    function test_WithdrawDoubleSpendReverts() public {
        bytes32 commitment = poseidon2(12345, 67890);
        vm.prank(depositor);
        pool.deposit{value: DENOM}(commitment);

        bytes32 root = pool.currentRoot();
        bytes32 nullifierHash = poseidon2(12345, 0);

        pool.withdraw(
            [uint256(1), uint256(2)],
            [[uint256(3), uint256(4)], [uint256(5), uint256(6)]],
            [uint256(7), uint256(8)],
            root, nullifierHash, recipient, relayer, 0
        );

        vm.expectRevert(AkmenaPrivatePool.NullifierAlreadySpent.selector);
        pool.withdraw(
            [uint256(1), uint256(2)],
            [[uint256(3), uint256(4)], [uint256(5), uint256(6)]],
            [uint256(7), uint256(8)],
            root, nullifierHash, recipient, relayer, 0
        );
    }

    function test_WithdrawUnknownRootReverts() public {
        bytes32 commitment = poseidon2(12345, 67890);
        vm.prank(depositor);
        pool.deposit{value: DENOM}(commitment);

        bytes32 fakeRoot = keccak256("fake");
        bytes32 nullifierHash = poseidon2(12345, 0);

        vm.expectRevert(AkmenaPrivatePool.UnknownRoot.selector);
        pool.withdraw(
            [uint256(1), uint256(2)],
            [[uint256(3), uint256(4)], [uint256(5), uint256(6)]],
            [uint256(7), uint256(8)],
            fakeRoot, nullifierHash, recipient, relayer, 0
        );
    }

    function test_WithdrawInvalidProofReverts() public {
        bytes32 commitment = poseidon2(12345, 67890);
        vm.prank(depositor);
        pool.deposit{value: DENOM}(commitment);

        mockVerifier.setShouldPass(false);

        bytes32 root = pool.currentRoot();
        bytes32 nullifierHash = poseidon2(12345, 0);

        vm.expectRevert(AkmenaPrivatePool.InvalidProof.selector);
        pool.withdraw(
            [uint256(1), uint256(2)],
            [[uint256(3), uint256(4)], [uint256(5), uint256(6)]],
            [uint256(7), uint256(8)],
            root, nullifierHash, recipient, relayer, 0
        );
    }

    function test_WithdrawFeeExceedsDenominationReverts() public {
        bytes32 commitment = poseidon2(12345, 67890);
        vm.prank(depositor);
        pool.deposit{value: DENOM}(commitment);

        bytes32 root = pool.currentRoot();
        bytes32 nullifierHash = poseidon2(12345, 0);

        vm.expectRevert(AkmenaPrivatePool.FeeExceedsDenomination.selector);
        pool.withdraw(
            [uint256(1), uint256(2)],
            [[uint256(3), uint256(4)], [uint256(5), uint256(6)]],
            [uint256(7), uint256(8)],
            root, nullifierHash, recipient, relayer, DENOM + 1
        );
    }

    function test_WithdrawZeroFeeSelfRelay() public {
        bytes32 commitment = poseidon2(999, 888);
        vm.prank(depositor);
        pool.deposit{value: DENOM}(commitment);

        uint256 recipientBefore = recipient.balance;
        // relayer = address(0), fee = 0: self-relay, full amount to recipient
        pool.withdraw(
            [uint256(1), uint256(2)],
            [[uint256(3), uint256(4)], [uint256(5), uint256(6)]],
            [uint256(7), uint256(8)],
            pool.currentRoot(), poseidon2(999, 0), recipient, payable(address(0)), 0
        );

        assertEq(recipient.balance - recipientBefore, DENOM);
    }

    function test_MultipleDepositsTreeConsistency() public {
        // Deposit 5 commitments, verify tree builds correctly
        // (each deposit changes the root)
        bytes32 prevRoot = pool.currentRoot();
        for (uint256 i = 0; i < 5; i++) {
            bytes32 commitment = poseidon2(i + 100, i + 200);
            vm.prank(depositor);
            pool.deposit{value: DENOM}(commitment);
            bytes32 newRoot = pool.currentRoot();
            assertTrue(newRoot != prevRoot, "root must change");
            assertTrue(pool.isKnownRoot(prevRoot), "old root in history");
            prevRoot = newRoot;
        }
        assertEq(pool.nextLeafIndex(), 5);
        assertEq(pool.anonymitySetSize(), 5);
    }

    function test_PubSignalsBinding() public {
        // Verify the contract passes the correct public signals to the verifier:
        // [root, nullifierHash, recipient, relayer, fee]
        bytes32 commitment = poseidon2(12345, 67890);
        vm.prank(depositor);
        pool.deposit{value: DENOM}(commitment);

        bytes32 root = pool.currentRoot();
        bytes32 nullifierHash = poseidon2(12345, 0);
        uint256 fee = 0.05 ether;

        uint256[5] memory expected = [
            uint256(root),
            uint256(nullifierHash),
            uint256(uint160(address(recipient))),
            uint256(uint160(address(relayer))),
            fee
        ];
        vm.expectEmit(true, false, false, true);
        emit MockVerifier.ProofChecked(expected);
        pool.withdraw(
            [uint256(1), uint256(2)],
            [[uint256(3), uint256(4)], [uint256(5), uint256(6)]],
            [uint256(7), uint256(8)],
            root, nullifierHash, recipient, relayer, fee
        );
    }
}
