// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {StealthAddressRegistry} from "../../../src/privacy/StealthAddressRegistry.sol";

contract StealthRegistryTest is Test {
    StealthAddressRegistry registry;
    address agent = address(0xAAAA); // Fixed valid hex

    function setUp() public {
        registry = new StealthAddressRegistry();
    }

    function test_RegisterAndRetrieveStealthMetaAddress() public {
        vm.startPrank(agent);
        uint256 schemeId = 1; // secp256k1
        bytes memory metaAddress = hex"020000000000000000000000000000000000000000000000000000000000000001";
        
        vm.expectEmit(true, true, false, true);
        emit StealthAddressRegistry.StealthMetaAddressSet(agent, schemeId, metaAddress);
        registry.registerStealthMetaAddress(schemeId, metaAddress);
        
        bytes memory retrieved = registry.getStealthMetaAddress(agent, schemeId);
        assertEq(retrieved, metaAddress);
        vm.stopPrank();
    }

    function test_AnnounceStealthTransaction() public {
        vm.startPrank(agent);
        uint256 schemeId = 1;
        address ephemeralStealthAddress = address(0xBBBB); // Fixed valid hex
        bytes memory ephemeralPubKey = hex"030000000000000000000000000000000000000000000000000000000000000002";
        bytes memory viewTag = hex"AA";

        vm.expectEmit(true, true, true, true);
        emit StealthAddressRegistry.Announcement(schemeId, ephemeralStealthAddress, agent, ephemeralPubKey, viewTag);
        
        registry.announce(schemeId, ephemeralStealthAddress, ephemeralPubKey, viewTag);
        vm.stopPrank();
    }
}
