// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {PrivacyEngine} from "../../src/privacy/PrivacyEngine.sol";

contract ProofSubjectIdentityTest is Test {
    PrivacyEngine internal privacy;

    address internal agent = address(0xAAAA);
    address payable internal recipient = payable(address(0xBBBB));

    function setUp() public {
        privacy = new PrivacyEngine();
    }

    function test_PrivacySettlementUsesRecipientAsCurrentProofSubject() public {
        bytes32 nullifierHash = keccak256("identity-test");
        bytes32 secret = keccak256("secret");
        uint256 amount = 1 ether;

        bytes32 commitment = keccak256(abi.encodePacked(nullifierHash, secret, amount, recipient));

        vm.deal(agent, amount);

        vm.prank(agent);
        privacy.depositPrivateEscrow{value: amount}(commitment);

        vm.prank(agent);
        privacy.executePrivateSettlement(nullifierHash, secret, amount, recipient);

        // This test intentionally documents the CURRENT semantic model.
        //
        // The privacy receipt is keyed to the recipient, not the caller.
        // We will use this invariant when deciding whether the proof
        // subject should remain recipient-scoped or become event-scoped.
        assertEq(recipient.balance, amount);
    }
}
