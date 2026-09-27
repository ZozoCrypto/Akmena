// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IDelegationEngine} from "./IDelegationEngine.sol";
import {LibStorage} from "../storage/LibStorage.sol";
import {IIdentity} from "../identity/IIdentity.sol";
import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

/// @title DelegationEngine
/// @notice Identity-scoped, capability-scoped execution delegation.
///
/// Security model:
/// - A delegation belongs to a canonical Identity address.
/// - Only the current Identity owner may create/revoke direct delegations.
/// - Signed delegations are authorized by the current Identity owner.
/// - Delegation does not grant capabilities by itself.
/// - Delegations expire and are capability-specific.
/// - Delegation cannot be chained recursively.
contract DelegationEngine is IDelegationEngine, EIP712 {
    bytes32 public constant DELEGATION_TYPEHASH = keccak256(
        "Delegation(address identity,address delegate,bytes32 capability,bool status,uint256 nonce,uint256 deadline)"
    );

    mapping(address => uint256) public nonces;

    constructor() EIP712("AkmenaDelegationEngine", "2") {}

    function setDelegate(address identity, address delegate, bytes32 capability, uint256 deadline, bool status)
        external
        override
    {
        _validateIdentity(identity);
        _validateDelegate(delegate);
        _validateCapability(capability);

        address owner = IIdentity(identity).owner();

        if (msg.sender != owner) {
            revert NotIdentityOwner();
        }

        if (status) {
            // Intentional timestamp boundary: delegations cannot be activated after expiry.
            // forge-lint: disable-next-line(block-timestamp)
            if (deadline <= block.timestamp) {
                revert DelegationExpired();
            }

            LibStorage.AuthorizationStorage storage ds = LibStorage.authorization();

            ds.delegationExpiries[identity][delegate][capability] = deadline;

            emit DelegateSet(identity, delegate, capability, deadline, true);
        } else {
            LibStorage.AuthorizationStorage storage ds = LibStorage.authorization();

            delete ds.delegationExpiries[identity][delegate][capability];

            emit DelegateSet(identity, delegate, capability, deadline, false);
        }
    }

    /// @notice Permissionless relay of an owner-signed delegation.
    /// @dev Signature authority is always the Identity's CURRENT owner.
    function setDelegateTyped(
        address identity,
        address delegate,
        bytes32 capability,
        uint256 deadline,
        bool status,
        bytes calldata signature
    ) external override {
        _validateIdentity(identity);
        _validateDelegate(delegate);
        _validateCapability(capability);

        // Intentional timestamp boundary: a typed delegation must not already be expired.
        // forge-lint: disable-next-line(block-timestamp)
        if (status && deadline <= block.timestamp) {
            revert DelegationExpired();
        }

        uint256 nonce = nonces[identity];

        bytes32 structHash =
            keccak256(abi.encode(DELEGATION_TYPEHASH, identity, delegate, capability, status, nonce, deadline));

        bytes32 digest = _hashTypedDataV4(structHash);

        address owner = IIdentity(identity).owner();

        if (!SignatureChecker.isValidSignatureNow(owner, digest, signature)) {
            revert InvalidSignature();
        }

        // Consume only after successful signature verification.
        nonces[identity] = nonce + 1;

        LibStorage.AuthorizationStorage storage ds = LibStorage.authorization();

        if (status) {
            ds.delegationExpiries[identity][delegate][capability] = deadline;
        } else {
            delete ds.delegationExpiries[identity][delegate][capability];
        }

        emit DelegateSet(identity, delegate, capability, deadline, status);
    }

    function isDelegate(address identity, address delegate, bytes32 capability) external view override returns (bool) {
        if (identity == address(0) || delegate == address(0) || capability == bytes32(0)) {
            return false;
        }

        LibStorage.AuthorizationStorage storage ds = LibStorage.authorization();

        uint256 deadline = ds.delegationExpiries[identity][delegate][capability];

        // Intentional timestamp boundary: delegation validity is defined by the stored expiry.
        // forge-lint: disable-next-line(block-timestamp)
        return deadline > block.timestamp && deadline != 0;
    }

    function _validateIdentity(address identity) internal view {
        if (identity == address(0) || identity.code.length == 0) {
            revert InvalidIdentity();
        }

        // Force interface compatibility and reject malformed identity objects.
        IIdentity(identity).identityId();
    }

    function _validateDelegate(address delegate) internal pure {
        if (delegate == address(0)) {
            revert InvalidAddress();
        }
    }

    function _validateCapability(bytes32 capability) internal pure {
        if (capability == bytes32(0)) {
            revert InvalidCapability();
        }
    }
}
