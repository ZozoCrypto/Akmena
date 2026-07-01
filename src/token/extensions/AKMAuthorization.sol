// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IAKMAuthorization} from "../../interfaces/IAKMAuthorization.sol";

/// @title AKMAuthorization
/// @notice Authorization engine powering AKM payment authorizations.
/// @dev Foundation for ERC-3009 payment operations.
abstract contract AKMAuthorization is IAKMAuthorization {
    using ECDSA for bytes32;

    // =============================================================
    //                           ERRORS
    // =============================================================

    error AuthorizationAlreadyUsed();
    error AuthorizationExpired();
    error AuthorizationNotYetValid();
    error InvalidSignature();

    // =============================================================
    //                        EIP-3009 TYPEHASHES
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

    mapping(address => mapping(bytes32 => bool)) internal _authorizationStates;

    // =============================================================
    //                           EVENTS
    // =============================================================

    event AuthorizationUsed(address indexed authorizer, bytes32 indexed nonce);

    event AuthorizationCanceled(address indexed authorizer, bytes32 indexed nonce);

    // =============================================================
    //                           VIEWS
    // =============================================================

    function authorizationState(address authorizer, bytes32 nonce) public view virtual override returns (bool) {
        return _authorizationStates[authorizer][nonce];
    }

    // =============================================================
    //                    INTERNAL TIME SOURCE
    // =============================================================

    function _currentTime() internal view virtual returns (uint256) {
        return block.timestamp;
    }

    // =============================================================
    //                 INTERNAL AUTHORIZATION LOGIC
    // =============================================================

    function _requireUnusedAuthorization(address authorizer, bytes32 nonce) internal view {
        if (_authorizationStates[authorizer][nonce]) {
            revert AuthorizationAlreadyUsed();
        }
    }

    function _useAuthorization(address authorizer, bytes32 nonce) internal {
        _authorizationStates[authorizer][nonce] = true;

        emit AuthorizationUsed(authorizer, nonce);
    }

    function _cancelAuthorization(address authorizer, bytes32 nonce) internal {
        _requireUnusedAuthorization(authorizer, nonce);

        _authorizationStates[authorizer][nonce] = true;

        emit AuthorizationCanceled(authorizer, nonce);
    }

    function _requireValidAuthorization(uint256 validAfter, uint256 validBefore) internal view {
        uint256 timestamp = _currentTime();

        if (timestamp <= validAfter) {
            revert AuthorizationNotYetValid();
        }

        if (timestamp >= validBefore) {
            revert AuthorizationExpired();
        }
    }

    // =============================================================
    //                 SIGNATURE VERIFICATION
    // =============================================================

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
