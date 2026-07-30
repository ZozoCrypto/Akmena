// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IMemoryEngine {
    event RootCommitted(bytes32 indexed key, bytes32 indexed rootHash);

    error EmptyKey();

    function commitRoot(bytes32 key, bytes32 rootHash) external;
    function getRoot(bytes32 key) external view returns (bytes32);
}
