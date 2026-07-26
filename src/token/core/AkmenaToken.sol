// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {AKMAuthorization} from "../extensions/AKMAuthorization.sol";
import {IAKMToken} from "../../interfaces/IAKMToken.sol";
import {AKMPayments} from "../extensions/AKMPayments.sol";

/// @title AkmenaToken
/// @notice Native settlement asset for the Akmena Protocol.
/// @dev Fixed-supply ERC20 with ERC2612 Permit and ERC3009 support.
contract AkmenaToken is ERC20, ERC20Permit, AKMPayments, IAKMToken {
    uint256 public constant MAX_SUPPLY = 1_000_000_000 ether;

    error InvalidInitialHolder();

    constructor(address initialHolder) ERC20("Akmena Token", "AKM") ERC20Permit("Akmena Token") {
        if (initialHolder == address(0)) {
            revert InvalidInitialHolder();
        }

        _mint(initialHolder, MAX_SUPPLY);
    }

    /// @inheritdoc IAKMToken
    function maxSupply() external pure returns (uint256) {
        return MAX_SUPPLY;
    }

    // =============================================================
    //                    INTERNAL PAYMENT HOOKS
    // =============================================================

    function _transferTokens(address from, address to, uint256 amount) internal override {
        _transfer(from, to, amount);
    }

    function _authorizationDigest(bytes32 structHash) internal view override returns (bytes32) {
        return _hashTypedDataV4(structHash);
    }

    // =============================================================
    //                    ERC-3009 INTERFACE OVERRIDES
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
    ) public override {
        super.transferWithAuthorization(from, to, value, validAfter, validBefore, nonce, v, r, s);
    }

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
    ) public override {
        super.receiveWithAuthorization(from, to, value, validAfter, validBefore, nonce, v, r, s);
    }

    function cancelAuthorization(address authorizer, bytes32 nonce, uint8 v, bytes32 r, bytes32 s)
        public
        override
    {
        super.cancelAuthorization(authorizer, nonce, v, r, s);
    }
}
