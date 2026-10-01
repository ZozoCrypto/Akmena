// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaPolicyBoundary} from "../../src/authorization/AkmenaPolicyBoundary.sol";
import {AkmenaCore} from "../../src/core/AkmenaCore.sol";
import {AkmenaExecutionAuthorization} from "../../src/authorization/AkmenaExecutionAuthorization.sol";

/// @title R11: Halmos symbolic verification for Model D boundary
/// @notice Halmos treats test parameters as symbolic values and attempts to
///         find counterexamples. If no counterexample exists, the property
///         holds for ALL possible inputs.
contract BoundarySymbolicR11 is Test {
    AkmenaCore internal core;
    AkmenaPolicyBoundary internal boundary;
    AkmenaExecutionAuthorization internal auth;

    address internal deployer = address(this);

    function setUp() public {
        core = new AkmenaCore();
        boundary = new AkmenaPolicyBoundary(address(core));
        auth = AkmenaExecutionAuthorization(boundary.executionAuthorization());
    }

    /// @notice SYMBOLIC: When protocol is paused, executeAuthorizedAgentCall
    ///         MUST revert for any intent parameters.
    /// @dev Halmos will search for ANY (intent, payload, signature) where
    ///      execution succeeds while paused. Finding none = property proven.
    ///      Uses low-level call because Halmos doesn't support expectRevert.
    function check_PauseBlocksExecution(
        address operator,
        address asset,
        address target,
        uint256 amount,
        uint256 nonce,
        bytes memory payload,
        bytes memory signature
    ) public {
        // Setup: pause the protocol
        core.setPaused(true);
        assertTrue(core.isPaused());

        // Construct intent with symbolic parameters
        AkmenaExecutionAuthorization.ExecutionIntent memory intent = AkmenaExecutionAuthorization.ExecutionIntent({
            operator: operator,
            agent: address(0x2002),
            target: target,
            selector: bytes4(0),
            calldataHash: keccak256(payload),
            asset: asset,
            amount: amount,
            value: 0,
            proofModuleKey: bytes32(0),
            proofId: 0,
            nonce: nonce,
            validAfter: 0,
            deadline: block.timestamp + 1 hours
        });

        // Attempt execution while paused via low-level call
        // If paused, this MUST fail (success == false)
        (bool success, ) = address(boundary).call(
            abi.encodeWithSelector(
                boundary.executeAuthorizedAgentCall.selector,
                intent,
                payload,
                signature
            )
        );
        
        // Property: success must be false (reverted) when paused
        // Halmos proves this by showing no counterexample exists where success == true
        assertTrue(!success);
    }

    /// @notice SYMBOLIC: A used (agent, nonce) pair MUST always revert (replay protection).
    /// @dev Marks usedNonces[agent][nonce]=true via vm.store, then proves that
    ///      ANY intent with that (agent, nonce) reverts, regardless of signature
    ///      validity or other parameters. This verifies the NonceAlreadyUsed
    ///      check is effective and fail-closed.
    ///      usedNonces is mapping(address => mapping(uint256 => bool)) at slot 2.
    function check_NonceReplayReverts(
        address agent,
        uint256 nonce,
        address operator,
        address asset,
        address target,
        uint256 amount,
        bytes memory payload,
        bytes memory signature
    ) public {
        // Setup: mark usedNonces[agent][nonce] = true via vm.store
        // Slot derivation: keccak256(nonce . keccak256(agent . 2))
        bytes32 innerSlot = keccak256(abi.encode(agent, uint256(2)));
        bytes32 nonceSlot = keccak256(abi.encode(nonce, innerSlot));
        vm.store(address(auth), nonceSlot, bytes32(uint256(1)));

        // Verify the nonce is marked used
        assertTrue(auth.usedNonces(agent, nonce));

        // Construct intent with the REPLAYED (agent, nonce)
        AkmenaExecutionAuthorization.ExecutionIntent memory intent = AkmenaExecutionAuthorization.ExecutionIntent({
            operator: operator,
            agent: agent,
            target: target,
            selector: bytes4(0),
            calldataHash: keccak256(payload),
            asset: asset,
            amount: amount,
            value: 0,
            proofModuleKey: bytes32(0),
            proofId: 0,
            nonce: nonce,
            validAfter: 0,
            deadline: block.timestamp + 1 hours
        });

        // Attempt execution with replayed nonce via low-level call
        // Halmos doesn't support expectRevert, so we check success==false
        (bool success, ) = address(boundary).call(
            abi.encodeWithSelector(
                boundary.executeAuthorizedAgentCall.selector,
                intent,
                payload,
                signature
            )
        );

        // Property: MUST revert (replay protection enforced)
        // Halmos proves this by showing no counterexample exists where success==true
        assertTrue(!success);
    }

    /// @notice SYMBOLIC: Zero-address operator must always revert
    /// @dev Uses low-level call because Halmos doesn't support expectRevert.
    function check_ZeroOperatorReverts(
        address asset,
        address target,
        uint256 amount,
        uint256 nonce,
        bytes memory payload,
        bytes memory signature
    ) public {
        AkmenaExecutionAuthorization.ExecutionIntent memory intent = AkmenaExecutionAuthorization.ExecutionIntent({
            operator: address(0), // symbolic zero
            agent: address(0x2002),
            target: target,
            selector: bytes4(0),
            calldataHash: keccak256(payload),
            asset: asset,
            amount: amount,
            value: 0,
            proofModuleKey: bytes32(0),
            proofId: 0,
            nonce: nonce,
            validAfter: 0,
            deadline: block.timestamp + 1 hours
        });

        (bool success, ) = address(boundary).call(
            abi.encodeWithSelector(
                boundary.executeAuthorizedAgentCall.selector,
                intent,
                payload,
                signature
            )
        );
        
        // Zero operator must always cause revert
        assertTrue(!success);
    }
}
