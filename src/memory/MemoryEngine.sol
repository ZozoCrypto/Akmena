// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IMemoryEngine} from "./IMemoryEngine.sol";
import {LibStorage} from "../storage/LibStorage.sol";

contract MemoryEngine is IMemoryEngine {
    function commitRoot(bytes32 key, bytes32 rootHash) external override {
        if (key == bytes32(0)) revert EmptyKey();

        LibStorage.MemoryStorage storage ds = LibStorage.memoryStorage();
        ds.root[key] = rootHash;

        emit RootCommitted(key, rootHash);
    }

    function getRoot(bytes32 key) external view override returns (bytes32) {
        return LibStorage.memoryStorage().root[key];
    }
}
