// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title EscrowErrors
/// @author Akmena Protocol
/// @notice Centralized error definitions for the Akmena Escrow Engine.
library EscrowErrors {
    error UntrustedToken();
    error InvalidTaskData();
    error TaskAlreadyExists();
    error TaskNotActive();
    error UnauthorizedArbiter();
    error DeadlineNotPassed();
    error DeadlinePassed();
}