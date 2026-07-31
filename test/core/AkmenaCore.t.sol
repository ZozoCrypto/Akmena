// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaCore} from "../../src/core/AkmenaCore.sol";
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
        treasuryEngine = new TreasuryEngine();
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
        (, bool status, ) = core.getModule(TREASURY_KEY);
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
}
