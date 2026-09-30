// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {AkmenaCore} from "../../src/core/AkmenaCore.sol";
import {PrivacyEngine} from "../../src/privacy/PrivacyEngine.sol";

/// @notice Simulates the DeployPrivacyEngine.s.sol remediation flow on a
///         Base Sepolia fork. Validates deployment + core registration work
///         against real chain state. Does NOT broadcast.
contract PrivacyEngineDeploySimTest is Test {
    address internal constant AKMENA_CORE = 0x0C4710331d6e234fE311C1c27252Ad63b7A6ac99;

    function setUp() public {
        try vm.createSelectFork("https://sepolia.base.org") {
            // Fork selected
        } catch {
            vm.skip(true);
        }
    }

    function test_SimulatePrivacyEngineDeployment() public {
        address coreDeployer = AkmenaCore(AKMENA_CORE).deployer();
        console.log("Core deployer:", coreDeployer);

        // Step 1: deploy the fixed PrivacyEngine (as the script does)
        PrivacyEngine privacy = new PrivacyEngine();
        console.log("PrivacyEngine deployed:", address(privacy));

        // Step 2: verify it's the FIXED build (has commitmentAmounts)
        // selector for commitmentAmounts(bytes32) = 0xbca44922
        (bool ok, bytes memory ret) = address(privacy).staticcall(
            abi.encodeWithSelector(bytes4(0xbca44922), bytes32(0))
        );
        assertTrue(ok, "commitmentAmounts selector missing - not the fixed build");
        assertEq(ret.length, 32, "unexpected return length");

        // Step 3: register with core (impersonating deployer, as the script
        // does via broadcast with the deployer key)
        vm.prank(coreDeployer);
        AkmenaCore(AKMENA_CORE).registerModule(
            keccak256("akmena.module.privacy"),
            address(privacy),
            "2.0.0"
        );

        // Step 4: verify registration
        (address registered,,) = AkmenaCore(AKMENA_CORE).getModule(keccak256("akmena.module.privacy"));
        assertEq(registered, address(privacy), "module not registered");
        console.log("Registered OK");
    }
}
