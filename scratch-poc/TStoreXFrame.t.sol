// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";

/// Minimal cross-frame EIP-1153 check: does tstore in one external call
/// remain visible to tload in a later external call within the same tx?
contract TStoreBox {
    function writeBox(bytes32 slot, bytes32 val) external {
        assembly {
            tstore(slot, val)
        }
    }

    function readBox(bytes32 slot) external view returns (bytes32 v) {
        assembly {
            v := tload(slot)
        }
    }
}

contract TStoreXFrameTest is Test {
    TStoreBox box = new TStoreBox();
    bytes32 constant SLOT = keccak256("xframe.test.slot");

    function test_CrossFrameTStoreTLoad() external {
        box.writeBox(SLOT, bytes32(uint256(0xBEEF)));
        bytes32 got = box.readBox(SLOT);
        emit log_named_bytes32("read back", got);
        assertEq(got, bytes32(uint256(0xBEEF)), "cross-frame transient storage broken");
    }

    function test_SameFrameTStoreTLoad() external {
        bytes32 slot = SLOT;
        bytes32 v;
        assembly {
            tstore(slot, 0xCAFE)
            v := tload(slot)
        }
        assertEq(v, bytes32(uint256(0xCAFE)), "same-frame transient storage broken");
    }
}
