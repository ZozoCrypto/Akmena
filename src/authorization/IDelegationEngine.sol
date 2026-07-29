// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IDelegationEngine {
    event DelegateSet(address indexed identity, address indexed delegate, bool status);

    error InvalidAddress();

    function setDelegate(address delegate, bool status) external;
    function isDelegate(address identity, address delegate) external view returns (bool);
}
