// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {AKMErrors} from "../lib/AKMErrors.sol";
import {AKMConstants} from "../lib/AKMConstants.sol";

abstract contract AkmenaAuthorization {
    mapping(address => mapping(bytes32 => bool)) public authorizationState;

    event AuthorizationUsed(address indexed authorizer, bytes32 indexed nonce);

    function _domainHash(bytes32 structHash) internal view virtual returns (bytes32);
    function _settleAuthorizedTransfer(address from, address to, uint256 value) internal virtual;

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
        if (block.timestamp <= validAfter || block.timestamp >= validBefore) revert AKMErrors.AuthorizationExpired();
        if (authorizationState[from][nonce]) revert AKMErrors.AuthorizationUsed();

        bytes32 structHash = keccak256(
            abi.encode(AKMConstants.TRANSFER_WITH_AUTHORIZATION_TYPEHASH, from, to, value, validAfter, validBefore, nonce)
        );

        bytes32 hash = _domainHash(structHash);
        address signer = ECDSA.recover(hash, v, r, s);

        if (signer != from) revert AKMErrors.InvalidSignature();

        authorizationState[from][nonce] = true;
        emit AuthorizationUsed(from, nonce);

        _settleAuthorizedTransfer(from, to, value);
    }
}