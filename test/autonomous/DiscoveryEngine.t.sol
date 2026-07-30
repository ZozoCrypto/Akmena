// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {DiscoveryEngine} from "../../src/autonomous/DiscoveryEngine.sol";
import {IDiscoveryEngine} from "../../src/autonomous/IDiscoveryEngine.sol";
import {LibStorage} from "../../src/storage/LibStorage.sol";

contract DiscoveryEngineTest is Test {
    DiscoveryEngine public engine;
    address public agent = address(0x444);
    bytes32 public constant CATEGORY = keccak256("DATA_ANALYSIS");
    string public constant URI = "ipfs://QmAgentMeta";

    function setUp() public {
        engine = new DiscoveryEngine();
    }

    function test_RegisterProfile() public {
        vm.prank(agent);
        vm.expectEmit(true, true, true, true);
        emit IDiscoveryEngine.AgentRegistered(agent, CATEGORY, URI);

        engine.registerProfile(CATEGORY, URI);
        
        LibStorage.DiscoveryData memory data = engine.getProfile(agent);
        assertEq(data.category, CATEGORY);
        assertEq(data.metadataURI, URI);
        assertTrue(data.isActive);
    }

    function test_UpdateStatus() public {
        vm.startPrank(agent);
        engine.registerProfile(CATEGORY, URI);
        
        vm.expectEmit(true, true, true, true);
        emit IDiscoveryEngine.AgentStatusUpdated(agent, false);
        
        engine.updateStatus(false);
        vm.stopPrank();

        LibStorage.DiscoveryData memory data = engine.getProfile(agent);
        assertFalse(data.isActive);
    }

    function test_RevertWhen_EmptyCategory() public {
        vm.expectRevert(IDiscoveryEngine.EmptyCategory.selector);
        engine.registerProfile(bytes32(0), URI);
    }
}
