// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "forge-std/StdInvariant.sol";
import "../../src/core/AkmenaCore.sol";

contract AkmenaInvariantsTest is StdInvariant, Test {
    AkmenaCore public core;
    address public deployer;

    function setUp() public {
        deployer = address(this);
        core = new AkmenaCore();
    }

    /// @notice Invariant: The deployer state must never be address zero
    function invariant_deployerNeverZero() public view {
        address currentDeployer = core.deployer();
        assertTrue(currentDeployer != address(0), "Deployer address must never be zero address");
    }

    /// @notice Invariant: Unregistered modules must always return address zero and inactive status
    function invariant_nonExistentModulesReturnDefaults() public view {
        bytes32 randomKey = keccak256(abi.encodePacked(block.timestamp, msg.sender));
        (address moduleAddr, bool active, string memory version) = core.getModule(randomKey);
        assertEq(moduleAddr, address(0), "Non-existent module must resolve to address zero");
        assertFalse(active, "Non-existent module must be inactive");
        bytes memory versionBytes = bytes(version);
        assertEq(versionBytes.length, 0, "Non-existent module version must be empty");
    }
}
