// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaEscrow} from "../../src/escrow/AkmenaEscrow.sol";
import {EscrowErrors} from "../../src/escrow/lib/EscrowErrors.sol";

contract MockToken {
    // Omitting variable names to silence the compiler warnings
    function transfer(address, uint256) external pure returns (bool) { return true; }
}

contract EscrowFuzzTest is Test {
    AkmenaEscrow public escrow;
    MockToken public mockToken;

    function setUp() public {
        mockToken = new MockToken();
        escrow = new AkmenaEscrow(address(mockToken));
    }

    // Fuzz Test 1: Ensure math holds up for ANY valid duration
    function testFuzz_ValidDurationMath(uint256 randomDuration) public {
        // Bound the fuzzer: pick any duration between 1 second and 30 days
        vm.assume(randomDuration > 0 && randomDuration <= 30 days);

        bytes32 taskId = bytes32("fuzz1");
        bytes memory data = abi.encode(taskId, address(0x2), address(0x3), randomDuration);

        vm.prank(address(mockToken));
        escrow.onTransferReceived(address(0), address(0x1), 100, data);

        // Verify the duration was stored exactly as fuzzed without overflow
        assertEq(escrow.getTask(taskId).duration, randomDuration);
    }

    // Fuzz Test 2: Ensure the safety lock CANNOT be bypassed
    function testFuzz_Revert_InvalidDurationSafety(uint256 randomDuration) public {
        // Bound the fuzzer: pick any duration mathematically greater than 30 days
        vm.assume(randomDuration > 30 days);

        bytes32 taskId = bytes32("fuzz2");
        bytes memory data = abi.encode(taskId, address(0x2), address(0x3), randomDuration);

        // Protocol MUST revert with InvalidTaskData
        vm.prank(address(mockToken));
        vm.expectRevert(EscrowErrors.InvalidTaskData.selector);
        escrow.onTransferReceived(address(0), address(0x1), 100, data);
    }
}