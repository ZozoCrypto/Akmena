// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title RegistryErrors
/// @author Akmena Protocol
/// @notice Centralized error definitions for the Akmena Registry Engine.
library RegistryErrors {
    error AgentAlreadyRegistered();
    error AgentNotRegistered();
    error UnauthorizedOwner();
    error InvalidStatusTransition();
    error AgentRevoked();
    error ZeroAddress();
}