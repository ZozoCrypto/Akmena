// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {PrivacyEngine} from "../../../src/privacy/PrivacyEngine.sol";

contract Attack_PrivacyRecipientBindingTest is Test {
    PrivacyEngine internal privacy;

    address internal depositor = address(0x1111);
    address internal attacker = address(0x2222);

    address payable internal intendedRecipient =
        payable(address(0x3333));

    address payable internal attackerRecipient =
        payable(address(0x4444));

    function setUp() public {
        privacy = new PrivacyEngine();
    }

    function _commitment(
        bytes32 nullifierHash,
        bytes32 secret,
        uint256 amount,
        address recipient
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                nullifierHash,
                secret,
                amount,
                recipient
            )
        );
    }

    function test_LegitimateSettlementToCommittedRecipient() public {
        uint256 amount = 5 ether;

        bytes32 secret = keccak256("legitimate-secret");
        bytes32 nullifierHash = keccak256("legitimate-nullifier");

        bytes32 commitment = _commitment(
            nullifierHash,
            secret,
            amount,
            intendedRecipient
        );

        vm.deal(depositor, amount);

        vm.prank(depositor);
        privacy.depositPrivateEscrow{value: amount}(commitment);

        uint256 recipientBefore = intendedRecipient.balance;

        // Settlement remains permissionless.
        vm.prank(attacker);
        privacy.executePrivateSettlement(
            nullifierHash,
            secret,
            amount,
            intendedRecipient
        );

        assertEq(
            intendedRecipient.balance,
            recipientBefore + amount,
            "Committed recipient did not receive funds"
        );

        assertTrue(
            privacy.nullifierHashes(nullifierHash),
            "Nullifier was not consumed"
        );

        assertFalse(
            privacy.commitments(commitment),
            "Commitment was not consumed"
        );
    }

    function test_Attack_RecipientSubstitutionFails() public {
        uint256 amount = 5 ether;

        bytes32 secret = keccak256("recipient-binding-secret");
        bytes32 nullifierHash =
            keccak256("recipient-binding-nullifier");

        bytes32 commitment = _commitment(
            nullifierHash,
            secret,
            amount,
            intendedRecipient
        );

        vm.deal(depositor, amount);

        vm.prank(depositor);
        privacy.depositPrivateEscrow{value: amount}(commitment);

        uint256 attackerBefore = attackerRecipient.balance;
        uint256 privacyBefore = address(privacy).balance;

        vm.prank(attacker);

        vm.expectRevert(
            PrivacyEngine.InvalidCommitment.selector
        );

        privacy.executePrivateSettlement(
            nullifierHash,
            secret,
            amount,
            attackerRecipient
        );

        assertEq(
            attackerRecipient.balance,
            attackerBefore,
            "CRITICAL: attacker-controlled recipient received funds"
        );

        assertEq(
            address(privacy).balance,
            privacyBefore,
            "CRITICAL: privacy pool funds moved"
        );

        assertFalse(
            privacy.nullifierHashes(nullifierHash),
            "Failed substitution attempt consumed nullifier"
        );

        assertTrue(
            privacy.commitments(commitment),
            "Failed substitution attempt consumed commitment"
        );
    }

    function test_WrongSecretFails() public {
        uint256 amount = 2 ether;

        bytes32 secret = keccak256("correct-secret");
        bytes32 wrongSecret = keccak256("wrong-secret");

        bytes32 nullifierHash = keccak256("wrong-secret-nullifier");

        bytes32 commitment = _commitment(
            nullifierHash,
            secret,
            amount,
            intendedRecipient
        );

        vm.deal(depositor, amount);

        vm.prank(depositor);
        privacy.depositPrivateEscrow{value: amount}(commitment);

        vm.expectRevert(
            PrivacyEngine.InvalidCommitment.selector
        );

        privacy.executePrivateSettlement(
            nullifierHash,
            wrongSecret,
            amount,
            intendedRecipient
        );

        assertTrue(
            privacy.commitments(commitment),
            "Commitment changed after wrong-secret attempt"
        );
    }

    function test_WrongAmountFails() public {
        uint256 amount = 3 ether;
        uint256 wrongAmount = 4 ether;

        bytes32 secret = keccak256("amount-secret");
        bytes32 nullifierHash = keccak256("amount-nullifier");

        bytes32 commitment = _commitment(
            nullifierHash,
            secret,
            amount,
            intendedRecipient
        );

        vm.deal(depositor, amount);

        vm.prank(depositor);
        privacy.depositPrivateEscrow{value: amount}(commitment);

        vm.expectRevert(
            PrivacyEngine.InvalidCommitment.selector
        );

        privacy.executePrivateSettlement(
            nullifierHash,
            secret,
            wrongAmount,
            intendedRecipient
        );

        assertTrue(
            privacy.commitments(commitment),
            "Commitment changed after wrong-amount attempt"
        );
    }

    function test_ReplayStillFails() public {
        uint256 amount = 1 ether;

        bytes32 secret = keccak256("replay-secret");
        bytes32 nullifierHash = keccak256("replay-nullifier");

        bytes32 commitment = _commitment(
            nullifierHash,
            secret,
            amount,
            intendedRecipient
        );

        vm.deal(depositor, amount);

        vm.prank(depositor);
        privacy.depositPrivateEscrow{value: amount}(commitment);

        privacy.executePrivateSettlement(
            nullifierHash,
            secret,
            amount,
            intendedRecipient
        );

        vm.expectRevert(
            PrivacyEngine.NullifierAlreadySpent.selector
        );

        privacy.executePrivateSettlement(
            nullifierHash,
            secret,
            amount,
            intendedRecipient
        );
    }

    function test_OldUnboundCommitmentCannotBeUsed() public {
        uint256 amount = 2 ether;

        bytes32 secret = keccak256("legacy-secret");
        bytes32 nullifierHash = keccak256("legacy-nullifier");

        // This is deliberately the vulnerable pre-fix commitment format.
        bytes32 oldCommitment = keccak256(
            abi.encodePacked(
                nullifierHash,
                secret,
                amount
            )
        );

        vm.deal(depositor, amount);

        vm.prank(depositor);
        privacy.depositPrivateEscrow{value: amount}(oldCommitment);

        vm.expectRevert(
            PrivacyEngine.InvalidCommitment.selector
        );

        privacy.executePrivateSettlement(
            nullifierHash,
            secret,
            amount,
            intendedRecipient
        );

        assertTrue(
            privacy.commitments(oldCommitment),
            "Legacy commitment should remain unspendable"
        );
    }
}
