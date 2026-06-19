// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title Akmena Protocol Errors
/// @notice Canonical custom errors used throughout the protocol.
library Errors {
    error Unauthorized();
    error ZeroAddress();
    error InvalidAgent();
    error AgentAlreadyExists();
    error AgentNotFound();
    error InvalidStateTransition();
    error InvalidAgreement();
}
