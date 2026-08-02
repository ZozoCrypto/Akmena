// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../../src/core/AkmenaCore.sol";
import "../../src/escrow/EscrowEngine.sol";

contract AkmenaSymbolicTest is Test {
    AkmenaCore public core;
    EscrowEngine public escrow;

    function setUp() public {
        core = new AkmenaCore();
        escrow = new EscrowEngine();
    }

    /// @notice Symbolic/Fuzz Proof: Non-deployer addresses can NEVER register a module
    function test_symbolic_unauthorizedRegisterReverts(address caller, bytes32 key, address module) public {
        vm.assume(caller != address(this)); // address(this) is deployer in setUp
        vm.assume(module != address(0));

        vm.prank(caller);
        vm.expectRevert();
        core.registerModule(key, module, "v2.0.0");
    }

    /// @notice Symbolic/Fuzz Proof: Unregistered escrow ID queries can never return a non-zero payer
    function test_symbolic_unregisteredEscrowHasZeroPayer(bytes32 symbolicEscrowId) public view {
        bool isExisting = escrow.exists(symbolicEscrowId);
        assertFalse(isExisting, "Unregistered escrow must non-exist for all symbolic bytes32 keys");
    }
}
