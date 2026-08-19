// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {AkmenaCore} from "../../../src/core/AkmenaCore.sol";
import {PrivacyEngine} from "../../../src/privacy/PrivacyEngine.sol";
import {StealthAddressRegistry} from "../../../src/privacy/StealthAddressRegistry.sol";

contract Integration_PrivateWorkflowTest is Test {
    AkmenaCore core;
    PrivacyEngine privacy;
    StealthAddressRegistry stealthRegistry;

    address buyerAgent = address(0xAAAA);
    address payable stealthRecipient = payable(address(0xBBBB));

    function setUp() public {
        core = new AkmenaCore();
        privacy = new PrivacyEngine();
        stealthRegistry = new StealthAddressRegistry();

        core.registerModule(bytes32("PRIVACY_ENGINE"), address(privacy), "1.0.0");
        core.registerModule(bytes32("STEALTH_REGISTRY"), address(stealthRegistry), "1.0.0");
    }

    function test_AgentPrivateSettlementFlow() public {
        // Step 1: Agent computes a stealth address & nullifier off-chain
        bytes32 secret = keccak256("agent-secret-key");
        bytes32 nullifierHash = keccak256("workflow-task-001");
        uint256 paymentAmount = 5 ether;
        
        bytes32 commitment = keccak256(abi.encodePacked(nullifierHash, secret, paymentAmount));

        // Step 2: Buyer Agent locks funds into the Privacy Pool
        vm.deal(buyerAgent, 10 ether);
        vm.prank(buyerAgent);
        privacy.depositPrivateEscrow{value: paymentAmount}(commitment);

        assertTrue(privacy.commitments(commitment), "Commitment not registered");
        assertEq(address(privacy).balance, paymentAmount, "Privacy engine missing funds");

        // Step 3: Workflow Completion -> Agent triggers private settlement
        // In production, the stealth address executes this to pull funds anonymously
        privacy.executePrivateSettlement(nullifierHash, secret, paymentAmount, stealthRecipient);

        // Verify state is clean and funds arrived
        assertEq(stealthRecipient.balance, paymentAmount, "Stealth recipient did not receive funds");
        assertFalse(privacy.commitments(commitment), "Commitment was not erased (Risk of double-spend!)");
        assertTrue(privacy.nullifierHashes(nullifierHash), "Nullifier not marked spent");
        
        console.log("Private Workflow successfully completed. Recipient balance:", stealthRecipient.balance);
    }
}
