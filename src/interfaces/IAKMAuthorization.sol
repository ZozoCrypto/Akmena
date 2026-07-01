// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title IAKMAuthorization
/// @notice ERC-3009 authorization interface for AKM.
interface IAKMAuthorization {
    /// @notice Returns whether an authorization nonce has been used.
    function authorizationState(address authorizer, bytes32 nonce) external view returns (bool);

    /// @notice Executes a signed transfer authorization.
    function transferWithAuthorization(
        address from,
        address to,
        uint256 value,
        uint256 validAfter,
        uint256 validBefore,
        bytes32 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /// @notice Executes a signed transfer where the recipient submits the authorization.
    function receiveWithAuthorization(
        address from,
        address to,
        uint256 value,
        uint256 validAfter,
        uint256 validBefore,
        bytes32 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /// @notice Cancels an unused authorization.
    function cancelAuthorization(address authorizer, bytes32 nonce, uint8 v, bytes32 r, bytes32 s) external;
}
