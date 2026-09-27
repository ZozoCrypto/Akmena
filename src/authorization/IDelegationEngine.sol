// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IDelegationEngine {
    event DelegateSet(
        address indexed identity, address indexed delegate, bytes32 indexed capability, uint256 deadline, bool status
    );

    error InvalidAddress();
    error InvalidIdentity();
    error InvalidCapability();
    error NotIdentityOwner();
    error DelegationExpired();
    error InvalidSignature();

    function setDelegate(address identity, address delegate, bytes32 capability, uint256 deadline, bool status) external;

    function setDelegateTyped(
        address identity,
        address delegate,
        bytes32 capability,
        uint256 deadline,
        bool status,
        bytes calldata signature
    ) external;

    function isDelegate(address identity, address delegate, bytes32 capability) external view returns (bool);

    function nonces(address identity) external view returns (uint256);
}
