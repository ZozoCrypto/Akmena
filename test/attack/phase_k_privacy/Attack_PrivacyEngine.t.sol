// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {PrivacyEngine} from "../../../src/privacy/PrivacyEngine.sol";

contract Attack_PrivacyEngineTest is Test {
    PrivacyEngine privacy;
    address attacker = address(0xBEEF);
    address recipient = address(0xCAFE);

    function setUp() public {
        privacy = new PrivacyEngine();
    }

    function test_Attack_DoubleSpendNullifier() public {
        bytes32 nullifierHash = keccak256("nullifier-1");
        bytes32 secret = keccak256("secret-1");
        uint256 amount = 1 ether;

        bytes32 commitment = keccak256(abi.encodePacked(nullifierHash, secret, amount));

        // 1. Initial Deposit
        vm.deal(attacker, 2 ether);
        vm.prank(attacker);
        privacy.depositPrivateEscrow{value: amount}(commitment);

        // 2. Legitimate First Withdrawal 
        privacy.executePrivateSettlement(nullifierHash, secret, amount, payable(recipient));
        assertEq(recipient.balance, amount);

        // 3. The Attack: Replay the identical nullifier and secret to double-spend
        vm.expectRevert(PrivacyEngine.NullifierAlreadySpent.selector);
        privacy.executePrivateSettlement(nullifierHash, secret, amount, payable(recipient));
    }

    function test_Attack_InvalidCommitment() public {
        bytes32 nullifierHash = keccak256("nullifier-unbacked");
        bytes32 secret = keccak256("secret-unbacked");
        uint256 amount = 1 ether;

        // The Attack: Attempting to settle funds from a commitment that was never mathematically locked
        vm.expectRevert(PrivacyEngine.InvalidCommitment.selector);
        privacy.executePrivateSettlement(nullifierHash, secret, amount, payable(recipient));
    }
}
