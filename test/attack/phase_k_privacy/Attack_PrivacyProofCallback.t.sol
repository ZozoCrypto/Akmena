// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {PrivacyEngine} from "../../../src/privacy/PrivacyEngine.sol";

contract PrivacyProofCallbackObserver {
    PrivacyEngine public immutable privacy;

    uint256 public observedProofId;
    uint256 public observedAmount;

    bool public callbackExecuted;
    bool public observedValid;

    constructor(PrivacyEngine _privacy) {
        privacy = _privacy;
    }

    function configure(
        uint256 proofId,
        uint256 amount
    ) external {
        observedProofId = proofId;
        observedAmount = amount;
    }

    receive() external payable {
        callbackExecuted = true;

        observedValid = privacy.verifyTransientProof(
            observedProofId,
            address(this),
            observedAmount
        );
    }
}

contract Attack_PrivacyProofCallbackTest is Test {
    PrivacyEngine internal privacy;
    PrivacyProofCallbackObserver internal observer;

    address internal depositor = address(0x1111);

    function setUp() public {
        privacy = new PrivacyEngine();
        observer = new PrivacyProofCallbackObserver(privacy);
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

    function test_RecipientCallbackCannotObservePrivacyProof()
        public
    {
        bytes32 nullifierHash =
            keccak256("callback-nullifier");

        bytes32 secret =
            keccak256("callback-secret");

        uint256 amount =
            5 ether;

        bytes32 commitment =
            _commitment(
                nullifierHash,
                secret,
                amount,
                address(observer)
            );

        observer.configure(
            uint256(nullifierHash),
            amount
        );

        vm.deal(depositor, amount);

        vm.prank(depositor);
        privacy.depositPrivateEscrow{value: amount}(
            commitment
        );

        uint256 observerBefore =
            address(observer).balance;

        privacy.executePrivateSettlement(
            nullifierHash,
            secret,
            amount,
            payable(address(observer))
        );

        assertTrue(
            observer.callbackExecuted(),
            "Recipient callback did not execute"
        );

        assertFalse(
            observer.observedValid(),
            "CRITICAL: recipient observed privacy proof during callback"
        );

        assertEq(
            address(observer).balance,
            observerBefore + amount,
            "Recipient did not receive settlement"
        );

        assertTrue(
            privacy.nullifierHashes(nullifierHash),
            "Nullifier was not consumed"
        );

        assertFalse(
            privacy.commitments(commitment),
            "Commitment was not consumed"
        );

        assertTrue(
            privacy.verifyTransientProof(
                uint256(nullifierHash),
                address(observer),
                amount
            ),
            "Proof was not published after successful settlement"
        );
    }
}
