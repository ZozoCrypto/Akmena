// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title AKMErrors
/// @author Akmena Protocol
/// @notice Centralized error registry for the entire Akmena protocol.
library AKMErrors {
    // Auth & Identity
    error AuthorizationExpired();
    error AuthorizationUsed();
    error InvalidSignature();
    error InvalidDuration();
    error Unauthorized();
    error Blacklisted();
    error ZeroAddress();
    
    // Transfer & 1363
    error TransferToNonContract();
    error ReceiverRejected();
    error SpenderRejected();
    error TransferFailed();
    error InvalidRecipient();
    
    // Escrow & Task logic
    error InvalidTaskData();
    error TaskAlreadyExists();
    error TaskNotActive();
    error UnauthorizedArbiter();
    error DeadlineNotPassed();
    error UntrustedToken();
}