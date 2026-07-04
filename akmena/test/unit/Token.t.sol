// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console2} from "forge-std/Test.sol";
import {AkmenaToken} from "../../src/token/AkmenaToken.sol";
import {IERC1363Receiver} from "../../src/token/interfaces/IERC1363Receiver.sol";
import {AKMConstants} from "../../src/token/lib/AKMConstants.sol";
import {AKMErrors} from "../../src/token/lib/AKMErrors.sol";

// ═════════════════════════════════════════════════════════════════════
// Mock Service (Acts as an AI Service or Escrow)
// ═════════════════════════════════════════════════════════════════════
contract MockReceiver is IERC1363Receiver {
    bool public wasTriggered;

    function onTransferReceived(address, address, uint256, bytes calldata) external returns (bytes4) {
        wasTriggered = true;
        return IERC1363Receiver.onTransferReceived.selector;
    }
}

// ═════════════════════════════════════════════════════════════════════
// The Test Suite
// ═════════════════════════════════════════════════════════════════════
contract TokenTest is Test {
    AkmenaToken public token;
    MockReceiver public receiver;

    address public treasury;
    address public alice;
    uint256 public alicePk = 0xA11CE; // Private key for generating Agent signatures
    address public bob = address(0xB0B);

    function setUp() public {
        treasury = address(this);
        alice = vm.addr(alicePk);
        
        token = new AkmenaToken(treasury);
        receiver = new MockReceiver();

        // Give Alice (the Agent) 1,000 AKM to start
    bool success = token.transfer(alice, 1000 * 1e18);
assertTrue(success, "Initial transfer failed");
    }

    /// @notice Tests if an Agent can pay and trigger a service in one transaction.
    function test_TransferAndCall_Success() public {
        vm.prank(alice); // Simulate Alice calling the contract
        token.transferAndCall(address(receiver), 100 * 1e18);
        
        // Assertions: Did the money move? Did the service unlock?
        assertEq(token.balanceOf(address(receiver)), 100 * 1e18);
        assertTrue(receiver.wasTriggered());
    }

    /// @notice Tests if the Kernel correctly processes an off-chain cryptographic intent.
    function test_TransferWithAuthorization_Success() public {
        uint256 value = 50 * 1e18;
        uint256 validAfter = 0;
        uint256 validBefore = block.timestamp + 1 hours;
        bytes32 nonce = keccak256("unique_nonce_1");

        // 1. Construct the exact EIP-712 Domain Separator the contract uses
        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("Akmena")),
                keccak256(bytes(AKMConstants.VERSION)),
                block.chainid,
                address(token)
            )
        );

        // 2. Hash the exact data payload
        bytes32 structHash = keccak256(
            abi.encode(
                AKMConstants.TRANSFER_WITH_AUTHORIZATION_TYPEHASH,
                alice,
                bob,
                value,
                validAfter,
                validBefore,
                nonce
            )
        );

        // 3. Combine Domain and Payload
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

        // 4. Alice (The Agent) signs the digest completely off-chain
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, digest);

        // 5. ANYONE can now submit this to the blockchain. We will simulate Bob submitting it.
        vm.prank(bob);
        token.transferWithAuthorization(
            alice, bob, value, validAfter, validBefore, nonce, v, r, s
        );

        // Assertion: Bob should now have the 50 AKM
        assertEq(token.balanceOf(bob), value);
    }
}