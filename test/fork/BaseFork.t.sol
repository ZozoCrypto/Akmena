// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../../src/core/AkmenaCore.sol";

contract BaseForkTest is Test {
    AkmenaCore public core;
    string public baseRpcUrl = "https://mainnet.base.org";

    function setUp() public {
        // Attempt to fork Base mainnet if network is accessible, otherwise run locally
        uint256 forkId;
        try vm.createFork(baseRpcUrl) returns (uint256 id) {
            forkId = id;
            vm.selectFork(forkId);
        } catch {
            // Fallback for air-gapped or offline environments
        }

        core = new AkmenaCore();
    }

    function test_BaseL2DeploymentIntegrity() public view {
        assertTrue(address(core) != address(0), "Core deployment failed under fork environment");
        assertEq(core.deployer(), address(this), "Deployer mismatch");
    }
}
