// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaCore} from "../../src/core/AkmenaCore.sol";
import {AkmenaToken} from "../../src/token/core/AkmenaToken.sol";
import {TreasuryEngine} from "../../src/economics/TreasuryEngine.sol";
import {MarketplaceEngine} from "../../src/autonomous/MarketplaceEngine.sol";

contract AkmenaCoreTest is Test {
    AkmenaCore public core;
    address public deployer = address(this);
    address public hacker = address(0xBAD);

    bytes32 public constant TREASURY_KEY = keccak256("akmena.module.treasury");
    bytes32 public constant MARKETPLACE_KEY = keccak256("akmena.module.marketplace");

    TreasuryEngine public treasuryEngine;
    MarketplaceEngine public marketplaceEngine;

    function setUp() public {
        core = new AkmenaCore();

        AkmenaToken token = new AkmenaToken(deployer);

        treasuryEngine = new TreasuryEngine(address(token), deployer);

        marketplaceEngine = new MarketplaceEngine();
    }

    function test_DeployerIsSet() public view {
        assertEq(core.deployer(), deployer);
    }

    function test_RegisterModules() public {
        // Updated to include the new 'version' string parameter
        vm.expectEmit(true, true, false, true);
        emit AkmenaCore.ModuleRegistered(TREASURY_KEY, address(treasuryEngine), "v2.0.0");

        core.registerModule(TREASURY_KEY, address(treasuryEngine), "v2.0.0");
        core.registerModule(MARKETPLACE_KEY, address(marketplaceEngine), "v2.0.0");

        (address tAddr, bool tStatus, string memory tVer) = core.getModule(TREASURY_KEY);
        assertEq(tAddr, address(treasuryEngine));
        assertTrue(tStatus);
        assertEq(tVer, "v2.0.0");
    }

    function test_SetModuleStatus() public {
        core.registerModule(TREASURY_KEY, address(treasuryEngine), "v2.0.0");

        core.setModuleStatus(TREASURY_KEY, false);
        (, bool status,) = core.getModule(TREASURY_KEY);
        assertFalse(status);
    }

    function test_RevertWhen_HackerTriesToRegister() public {
        vm.prank(hacker);
        vm.expectRevert(AkmenaCore.UnauthorizedAccess.selector);
        core.registerModule(TREASURY_KEY, address(treasuryEngine), "v2.0.0");
    }

    function test_RevertWhen_ZeroAddressModule() public {
        vm.expectRevert(AkmenaCore.InvalidModuleAddress.selector);
        core.registerModule(TREASURY_KEY, address(0), "v2.0.0");
    }

    function test_RevertWhen_RegisteringDuplicateModule() public {
        core.registerModule(TREASURY_KEY, address(treasuryEngine), "v2.0.0");

        vm.expectRevert(AkmenaCore.ModuleAlreadyRegistered.selector);
        core.registerModule(TREASURY_KEY, address(treasuryEngine), "v2.0.0");
    }

    /// @notice R10 mutant-14 regression: setModuleStatus(key, true) must
    /// actually enable the module. Mutant 14 hardcoded enabled=false.
    function test_R10_ModuleEnableTakesEffect() public {
        core.registerModule(TREASURY_KEY, address(treasuryEngine), "v2.0.0");
        core.setModuleStatus(TREASURY_KEY, false);
        (, bool enabledAfterDisable,) = core.getModule(TREASURY_KEY);
        assertFalse(enabledAfterDisable, "disable must take effect");

        core.setModuleStatus(TREASURY_KEY, true);
        (, bool enabledAfterEnable,) = core.getModule(TREASURY_KEY);
        assertTrue(enabledAfterEnable, "enable must take effect");
    }

    /// @notice R10 mutant-15 regression: guardian must NOT be able to unpause.
    /// Unpause is deployer-only (spec 7.1). Mutant 15 routed unpause through
    /// the pause-branch auth (guardian-or-deployer).
    function test_R10_GuardianCannotUnpause() public {
        address guardian = address(0x6A7);
        core.setPauseGuardian(guardian);

        // Deployer pauses.
        core.setPaused(true);
        assertTrue(core.isPaused());

        // Guardian attempts unpause: must revert.
        vm.prank(guardian);
        vm.expectRevert(AkmenaCore.UnauthorizedAccess.selector);
        core.setPaused(false);

        assertTrue(core.isPaused(), "guardian unpause must not succeed");
    }

    /// @notice R10 mutant-16 regression: guardian MUST be able to pause
    /// (containment). Mutant 16 routed pause through deployer-only auth.
    function test_R10_GuardianCanPause() public {
        address guardian = address(0x6A7);
        core.setPauseGuardian(guardian);

        vm.prank(guardian);
        core.setPaused(true);

        assertTrue(core.isPaused(), "guardian pause must succeed");
    }

    /// @notice R10 mutant-17 regression (CRITICAL): unauthorized callers must
    /// NOT be able to unpause. Mutant 17 removed the deployer check entirely.
    function test_R10_NonDeployerCannotUnpause() public {
        core.setPaused(true);
        assertTrue(core.isPaused());

        vm.prank(hacker);
        vm.expectRevert(AkmenaCore.UnauthorizedAccess.selector);
        core.setPaused(false);

        assertTrue(core.isPaused(), "hacker unpause must not succeed");
    }

    /// @notice R10 mutant-20 regression: setPauseGuardian must actually store
    /// the guardian. Mutant 20 replaced the assignment with assert(true).
    function test_R10_PauseGuardianSetCorrectly() public {
        address guardian = address(0x6A7);
        core.setPauseGuardian(guardian);
        assertEq(core.pauseGuardian(), guardian, "guardian must be stored");
    }

    /// @notice R10: deployer can unpause (positive path for mutant 15/17).
    function test_R10_DeployerCanUnpause() public {
        core.setPaused(true);
        assertTrue(core.isPaused());

        core.setPaused(false);
        assertFalse(core.isPaused(), "deployer unpause must succeed");
    }
}
