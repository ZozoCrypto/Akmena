// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {MemoryEngine} from "../../src/memory/MemoryEngine.sol";
import {IMemoryEngine} from "../../src/memory/IMemoryEngine.sol";

contract MemoryEngineTest is Test {
    MemoryEngine public engine;
    bytes32 public key = keccak256("AI_STATE_ROOT");
    bytes32 public rootHash = keccak256("DATA_PAYLOAD");

    function setUp() public {
        engine = new MemoryEngine();
    }

    function test_CommitAndGetRoot() public {
        vm.expectEmit(true, true, true, true);
        emit IMemoryEngine.RootCommitted(key, rootHash);

        engine.commitRoot(key, rootHash);
        assertEq(engine.getRoot(key), rootHash);
    }

    function test_RevertWhen_EmptyKey() public {
        vm.expectRevert(IMemoryEngine.EmptyKey.selector);
        engine.commitRoot(bytes32(0), rootHash);
    }
}
