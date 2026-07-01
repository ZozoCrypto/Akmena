// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {AKMAuthorization} from "./AKMAuthorization.sol";

/// @title AKMPayments
/// @notice ERC-3009 payment execution engine for AKM.
abstract contract AKMPayments is AKMAuthorization {
    using ECDSA for bytes32;

    // =============================================================
    //                           EVENTS
    // =============================================================

    event AuthorizationTransfer(address indexed from, address indexed to, uint256 value, bytes32 indexed nonce);

    // =============================================================
    //                     ABSTRACT HOOKS
    // =============================================================

    /// @dev Implemented by AkmenaToken.
    function _transferTokens(address from, address to, uint256 amount) internal virtual;

    /// @dev Returns the EIP-712 digest.
    function _authorizationDigest(bytes32 structHash) internal view virtual returns (bytes32);

    // =============================================================
    //             TRANSFER WITH AUTHORIZATION
    // =============================================================

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
    ) public virtual {
        _requireUnusedAuthorization(from, nonce);
        _requireValidAuthorization(validAfter, validBefore);

        bytes32 structHash = keccak256(
            abi.encode(TRANSFER_WITH_AUTHORIZATION_TYPEHASH, from, to, value, validAfter, validBefore, nonce)
        );

        bytes32 digest = _authorizationDigest(structHash);

        _verifySigner(from, digest, v, r, s);

        _useAuthorization(from, nonce);

        _transferTokens(from, to, value);

        emit AuthorizationTransfer(from, to, value, nonce);
    }

    // =============================================================
    //            RECEIVE WITH AUTHORIZATION
    // =============================================================

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
    ) public virtual {
        require(msg.sender == to, "AKM: caller must be recipient");

        _requireUnusedAuthorization(from, nonce);
        _requireValidAuthorization(validAfter, validBefore);

        bytes32 structHash =
            keccak256(abi.encode(RECEIVE_WITH_AUTHORIZATION_TYPEHASH, from, to, value, validAfter, validBefore, nonce));

        bytes32 digest = _authorizationDigest(structHash);

        _verifySigner(from, digest, v, r, s);

        _useAuthorization(from, nonce);

        _transferTokens(from, to, value);

        emit AuthorizationTransfer(from, to, value, nonce);
    }

    // =============================================================
    //              CANCEL AUTHORIZATION
    // =============================================================

    function cancelAuthorization(address authorizer, bytes32 nonce, uint8 v, bytes32 r, bytes32 s) public virtual {
        _requireUnusedAuthorization(authorizer, nonce);

        bytes32 structHash = keccak256(abi.encode(CANCEL_AUTHORIZATION_TYPEHASH, authorizer, nonce));

        bytes32 digest = _authorizationDigest(structHash);

        _verifySigner(authorizer, digest, v, r, s);

        _cancelAuthorization(authorizer, nonce);
    }
}
