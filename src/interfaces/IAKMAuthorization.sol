// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title IAKMAuthorization
/// @notice ERC-3009 inspired authorization interface for AKM autonomous payments.
interface IAKMAuthorization {
    struct Authorization {
        address from;
        address to;
        uint256 value;
        uint256 validAfter;
        uint256 validBefore;
        bytes32 nonce;
    }

    event AuthorizationUsed(address indexed authorizer, bytes32 indexed nonce);

    event AuthorizationCanceled(address indexed authorizer, bytes32 indexed nonce);

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

    function cancelAuthorization(address authorizer, bytes32 nonce, uint8 v, bytes32 r, bytes32 s) external;

    function authorizationState(address authorizer, bytes32 nonce) external view returns (bool);
}
