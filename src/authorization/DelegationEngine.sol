// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IDelegationEngine} from "./IDelegationEngine.sol";
import {LibStorage} from "../storage/LibStorage.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract DelegationEngine is IDelegationEngine, EIP712 {
    using ECDSA for bytes32;

    bytes32 private constant SET_DELEGATE_TYPEHASH = keccak256("SetDelegate(address delegate,bool status,uint256 nonce,uint256 deadline)");
    mapping(address => uint256) public nonces;

    constructor() EIP712("AkmenaDelegationEngine", "1") {}

    function setDelegate(address delegate, bool status) external override {
        if (delegate == address(0)) revert InvalidAddress();

        LibStorage.AuthorizationStorage storage ds = LibStorage.authorization();
        ds.delegates[msg.sender][delegate] = status;

        emit DelegateSet(msg.sender, delegate, status);
    }

    /// @notice FORTIFIED: Cryptographically verified delegate assignment via EIP-712 signature
    function setDelegateTyped(
        address owner,
        address delegate,
        bool status,
        uint256 deadline,
        bytes calldata signature
    ) external {
        if (owner == address(0) || delegate == address(0)) revert InvalidAddress();
        require(block.timestamp <= deadline, "Signature expired");

        uint256 currentNonce = nonces[owner]++;
        bytes32 structHash = keccak256(abi.encode(SET_DELEGATE_TYPEHASH, delegate, status, currentNonce, deadline));
        bytes32 hash = _hashTypedDataV4(structHash);
        
        address signer = hash.recover(signature);
        require(signer == owner, "Invalid signature");

        LibStorage.AuthorizationStorage storage ds = LibStorage.authorization();
        ds.delegates[owner][delegate] = status;

        emit DelegateSet(owner, delegate, status);
    }

    function isDelegate(address identity, address delegate) external view override returns (bool) {
        if (identity == address(0) || delegate == address(0)) return false;

        LibStorage.AuthorizationStorage storage ds = LibStorage.authorization();
        return ds.delegates[identity][delegate];
    }
}
