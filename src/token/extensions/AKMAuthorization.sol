// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/// @title AKMAuthorization
/// @notice Authorization engine powering AKM autonomous commerce.
/// @dev Foundation for ERC-3009 and future AKM payment protocols.
abstract contract AKMAuthorization {
    using ECDSA for bytes32;

    // =============================================================
    //                           ERRORS
    // =============================================================

    error AuthorizationAlreadyUsed();
    error InvalidSignature();
    error AuthorizationExpired();
    error AuthorizationNotYetValid();

    // =============================================================
    //                        TYPE HASHES
    // =============================================================

    bytes32 internal constant TRANSFER_WITH_AUTHORIZATION_TYPEHASH = keccak256(
        "TransferWithAuthorization(address from,address to,uint256 value,uint256 validAfter,uint256 validBefore,bytes32 nonce)"
    );

    bytes32 internal constant RECEIVE_WITH_AUTHORIZATION_TYPEHASH = keccak256(
        "ReceiveWithAuthorization(address from,address to,uint256 value,uint256 validAfter,uint256 validBefore,bytes32 nonce)"
    );

    bytes32 internal constant CANCEL_AUTHORIZATION_TYPEHASH =
        keccak256("CancelAuthorization(address authorizer,bytes32 nonce)");

    // =============================================================
    //                          STORAGE
    // =============================================================

    mapping(address => mapping(bytes32 => bool)) internal _authorizationUsed;

    // =============================================================
    //                           EVENTS
    // =============================================================

    event AuthorizationUsed(address indexed authorizer, bytes32 indexed nonce);

    event AuthorizationCanceled(address indexed authorizer, bytes32 indexed nonce);

    // =============================================================
    //                      TIME ABSTRACTION
    // =============================================================

    function _currentTime() internal view virtual returns (uint256) {
        return block.timestamp;
    }

    // =============================================================
    //                      VIEW FUNCTIONS
    // =============================================================

    function authorizationState(address authorizer, bytes32 nonce) public view returns (bool) {
        return _authorizationUsed[authorizer][nonce];
    }

    // =============================================================
    //                    INTERNAL FUNCTIONS
    // =============================================================

    function _requireUnusedAuthorization(address authorizer, bytes32 nonce) internal view {
        if (_authorizationUsed[authorizer][nonce]) {
            revert AuthorizationAlreadyUsed();
        }
    }

    function _markAuthorizationAsUsed(address authorizer, bytes32 nonce) internal {
        _authorizationUsed[authorizer][nonce] = true;

        emit AuthorizationUsed(authorizer, nonce);
    }

    function _cancelAuthorization(address authorizer, bytes32 nonce) internal {
        _requireUnusedAuthorization(authorizer, nonce);

        _authorizationUsed[authorizer][nonce] = true;

        emit AuthorizationCanceled(authorizer, nonce);
    }

    function _requireValidAuthorization(uint256 validAfter, uint256 validBefore) internal view {
        uint256 currentTime = _currentTime();

        if (currentTime <= validAfter) {
            revert AuthorizationNotYetValid();
        }

        if (currentTime >= validBefore) {
            revert AuthorizationExpired();
        }
    }

    function _recoverSigner(bytes32 digest, uint8 v, bytes32 r, bytes32 s) internal pure returns (address) {
        return ECDSA.recover(digest, v, r, s);
    }

    function _verifySigner(address expectedSigner, bytes32 digest, uint8 v, bytes32 r, bytes32 s) internal pure {
        address recovered = _recoverSigner(digest, v, r, s);

        if (recovered != expectedSigner) {
            revert InvalidSignature();
        }
    }
}
