// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title IArbiter
/// @author Akmena Protocol
/// @notice The standard interface for entities resolving Akmena Escrows.
/// @dev Can be implemented by Oracles (data-driven) or Master Agents (subjective).
interface IArbiter {
    /// @notice Evaluates a task and potentially resolves it.
    /// @param escrowAddress The address of the Akmena Escrow contract holding the task.
    /// @param taskId The unique identifier of the task.
    /// @param data Optional payload containing proof, oracle data, or agent signatures.
    /// @return success True if the task was evaluated and resolved successfully.
    function evaluateTask(address escrowAddress, bytes32 taskId, bytes calldata data) external returns (bool success);
}