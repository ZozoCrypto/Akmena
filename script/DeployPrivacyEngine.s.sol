// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";

import {AkmenaCore} from "../src/core/AkmenaCore.sol";
import {PrivacyEngine} from "../src/privacy/PrivacyEngine.sol";

/// @notice Deploys the FIXED PrivacyEngine to Base Sepolia and registers it
///         with the existing AkmenaCore.
///
/// @dev Remediation for PRIVACYENGINE_PROVENANCE_2026-09-30.md:
///      - The frontend's configured privacyEngine address has no code.
///      - The previous address hosts the pre-fix (drainable) build.
///      This script deploys the fixed build (with commitmentAmounts) and
///      registers it under akmena.module.privacy.
///
///      Run with:
///        forge script script/DeployPrivacyEngine.s.sol:DeployPrivacyEngine \
///          --rpc-url https://sepolia.base.org --broadcast --verify \
///          --etherscan-api-key $BASESCAN_API_KEY
///
///      Requires PRIVATE_KEY env var (deployer = AkmenaCore deployer).
contract DeployPrivacyEngine is Script {
    // Existing AkmenaCore on Base Sepolia (from frontend/src/config.ts)
    address internal constant AKMENA_CORE = 0x0C4710331d6e234fE311C1c27252Ad63b7A6ac99;

    function run() external {
        require(block.chainid == 84532, "DeployPrivacyEngine: Base Sepolia only");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Sanity: deployer must be the AkmenaCore deployer to register the module.
        address coreDeployer = AkmenaCore(AKMENA_CORE).deployer();
        require(deployer == coreDeployer, "DeployPrivacyEngine: not core deployer");

        vm.startBroadcast(deployerPrivateKey);

        PrivacyEngine privacy = new PrivacyEngine();
        console.log("PrivacyEngine deployed:", address(privacy));

        AkmenaCore(AKMENA_CORE).registerModule(
            keccak256("akmena.module.privacy"),
            address(privacy),
            "2.0.0"
        );
        console.log("Registered akmena.module.privacy ->", address(privacy));

        vm.stopBroadcast();
    }
}
