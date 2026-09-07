// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {PrivacyEngine} from "../../../src/privacy/PrivacyEngine.sol";

contract AttackPrivacyValueBindingTest is Test {
    PrivacyEngine internal privacy;

    address internal depositor = address(0x1111);
    address internal victim = address(0x2222);
    address payable internal recipient = payable(address(0x3333));

    function setUp() public {
        privacy = new PrivacyEngine();
    }

    function test_UndercollateralizedCommitmentCannotRedeemPooledBalance()
        public
    {
        uint256 depositedAmount = 1 wei;
        uint256 committedAmount = 10 ether;

        bytes32 nullifierHash = keccak256("undercollateralized-nullifier");
        bytes32 secret = keccak256("undercollateralized-secret");

        bytes32 attackerCommitment = keccak256(
            abi.encodePacked(
                nullifierHash,
                secret,
                committedAmount,
                recipient
            )
        );

        // Attacker funds the commitment with only 1 wei.
        vm.deal(depositor, depositedAmount);
        vm.prank(depositor);
        privacy.depositPrivateEscrow{value: depositedAmount}(
            attackerCommitment
        );

        // Simulate another user's legitimate privacy deposit,
        // creating pooled liquidity inside the PrivacyEngine.
        bytes32 victimNullifier = keccak256("victim-nullifier");
        bytes32 victimSecret = keccak256("victim-secret");
        bytes32 victimCommitment = keccak256(
            abi.encodePacked(
                victimNullifier,
                victimSecret,
                committedAmount,
                recipient
            )
        );

        vm.deal(victim, committedAmount);
        vm.prank(victim);
        privacy.depositPrivateEscrow{value: committedAmount}(
            victimCommitment
        );

        assertEq(
            address(privacy).balance,
            depositedAmount + committedAmount
        );

        vm.expectRevert(PrivacyEngine.InvalidCommitment.selector);

        privacy.executePrivateSettlement(
            nullifierHash,
            secret,
            committedAmount,
            recipient
        );

        assertEq(
            recipient.balance,
            0,
            "CRITICAL: undercollateralized commitment withdrew pooled funds"
        );
    }

    function test_ExactDepositAmountCanBeSettled()
        public
    {
        uint256 amount = 1 ether;

        bytes32 nullifierHash = keccak256("valid-nullifier");
        bytes32 secret = keccak256("valid-secret");

        bytes32 commitment = keccak256(
            abi.encodePacked(
                nullifierHash,
                secret,
                amount,
                recipient
            )
        );

        vm.deal(depositor, amount);
        vm.prank(depositor);
        privacy.depositPrivateEscrow{value: amount}(commitment);

        privacy.executePrivateSettlement(
            nullifierHash,
            secret,
            amount,
            recipient
        );

        assertEq(recipient.balance, amount);
        assertEq(address(privacy).balance, 0);
        assertEq(privacy.commitmentAmounts(commitment), 0);
    }
}
