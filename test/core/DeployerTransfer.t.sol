// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaCore} from "../../src/core/AkmenaCore.sol";

/// @notice Tests for the two-step deployer transfer mechanism (2026-10-01).
/// @dev The deployer role was previously immutable. This implements the G-7 requirement
/// that the deployer can be transferred to the timelock after migration.
contract DeployerTransferTest is Test {
    AkmenaCore public core;

    address public deployer = address(0x100);
    address public newDeployer = address(0x200);
    address public attacker = address(0x300);

    function setUp() public {
        vm.prank(deployer);
        core = new AkmenaCore();
    }

    function test_DeployerSetAtConstruction() public view {
        assertEq(core.deployer(), deployer, "Deployer should be set at construction");
    }

    function test_ProposeDeployer() public {
        vm.prank(deployer);
        core.proposeDeployer(newDeployer);
        assertEq(core.pendingDeployer(), newDeployer, "Pending deployer should be set");
        // Current deployer retains powers until acceptance
        assertEq(core.deployer(), deployer, "Deployer unchanged until accept");
    }

    function test_ProposeDeployerRevertsForNonDeployer() public {
        vm.prank(attacker);
        vm.expectRevert(AkmenaCore.UnauthorizedAccess.selector);
        core.proposeDeployer(newDeployer);
    }

    function test_ProposeDeployerRevertsForZeroAddress() public {
        vm.prank(deployer);
        vm.expectRevert(AkmenaCore.InvalidDeployer.selector);
        core.proposeDeployer(address(0));
    }

    function test_AcceptDeployer() public {
        vm.prank(deployer);
        core.proposeDeployer(newDeployer);

        vm.prank(newDeployer);
        core.acceptDeployer();

        assertEq(core.deployer(), newDeployer, "Deployer should transfer");
        assertEq(core.pendingDeployer(), address(0), "Pending should clear");
    }

    function test_AcceptDeployerRevertsForNonProposed() public {
        vm.prank(deployer);
        core.proposeDeployer(newDeployer);

        vm.prank(attacker);
        vm.expectRevert(AkmenaCore.UnauthorizedAccess.selector);
        core.acceptDeployer();
    }

    function test_AcceptDeployerRevertsWithNoPending() public {
        vm.prank(newDeployer);
        vm.expectRevert(AkmenaCore.NoPendingTransfer.selector);
        core.acceptDeployer();
    }

    function test_OldDeployerLosesPowersAfterTransfer() public {
        vm.prank(deployer);
        core.proposeDeployer(newDeployer);
        vm.prank(newDeployer);
        core.acceptDeployer();

        // Old deployer can no longer pause
        vm.prank(deployer);
        vm.expectRevert(AkmenaCore.UnauthorizedAccess.selector);
        core.setPaused(true);

        // New deployer can pause
        vm.prank(newDeployer);
        core.setPaused(true);
        assertTrue(core.isPaused(), "New deployer should pause");
    }

    function test_CancelDeployerTransfer() public {
        vm.prank(deployer);
        core.proposeDeployer(newDeployer);
        assertEq(core.pendingDeployer(), newDeployer);

        vm.prank(deployer);
        core.cancelDeployerTransfer();
        assertEq(core.pendingDeployer(), address(0), "Pending should clear on cancel");

        // Accept should now fail
        vm.prank(newDeployer);
        vm.expectRevert(AkmenaCore.NoPendingTransfer.selector);
        core.acceptDeployer();
    }

    function test_CancelDeployerTransferRevertsForNonDeployer() public {
        vm.prank(deployer);
        core.proposeDeployer(newDeployer);

        vm.prank(attacker);
        vm.expectRevert(AkmenaCore.UnauthorizedAccess.selector);
        core.cancelDeployerTransfer();
    }

    function test_DeployerCanTransferToTimelock() public {
        // Simulates the G-7 migration: deployer transfers to a timelock address
        address timelock = address(0x400);
        vm.prank(deployer);
        core.proposeDeployer(timelock);
        vm.prank(timelock);
        core.acceptDeployer();
        assertEq(core.deployer(), timelock, "Deployer should be timelock after G-7");
    }
}
