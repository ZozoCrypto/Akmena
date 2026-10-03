// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {AkmenaCore} from "../src/core/AkmenaCore.sol";
import {AkmenaPolicyBoundary} from "../src/authorization/AkmenaPolicyBoundary.sol";

/// @title DeployG7Governance
/// @notice Deploys G-7 governance: TimelockController + configures roles
/// @dev TEMPORARY BUILD/REHEARSAL CONFIGURATION
///
/// TEMPORARY ADDRESSES (2026-10-03, Elijah):
/// - Pause guardian: 0x2dd10bb5571f9086c789fd8c5e2b43545b74444f
/// - Safe owner #1: 0x2D4888499D765d387f9CbC48061b28CDe6bC2601 (Elijah)
/// - Safe owner #2: 0x002176469C1c635530c4AC30767dF1B9fbF529a3
/// - Safe owner #3: 0xC72CBbeaf7F540522804BcbF592dc7a6b6906476
/// - Threshold: 2-of-3
///
/// ⚠️  THESE ARE TEMPORARY. Do NOT treat as production custody.
/// Final production Safe configuration is PENDING Elijah's decision.
///
/// The Safe itself must be deployed separately (via Safe UI or safe-smart-account).
/// This script:
/// 1. Deploys TimelockController (24h delay)
/// 2. Configures AkmenaCore roles (pauseGuardian, allowlistAdmin, emergencyAdmin)
/// 3. Proposes deployer transfer to timelock (requires timelock to accept)
///
/// Signer rotation procedure: see G7_SIGNER_ROTATION.md
contract DeployG7Governance is Script {
    // ── Temporary configuration (explicit parameters) ──
    // Override via env: PAUSE_GUARDIAN, TIMELOCK_DELAY, SAFE_ADDRESS

    /// @dev Temporary pause guardian — REPLACE before production
    address constant TEMP_PAUSE_GUARDIAN = 0x2DD10Bb5571F9086C789fD8C5e2B43545B74444f;

    /// @dev 24h timelock delay (per G-7 decision)
    uint256 constant TIMELOCK_DELAY = 24 hours;

    function run() external {
        // ── Read explicit parameters ──
        address coreAddress = vm.envAddress("AKMENA_CORE");
        address boundaryAddress = vm.envAddress("AKMENA_BOUNDARY");
        address safeAddress = vm.envAddress("SAFE_ADDRESS"); // 2-of-3 Safe (deployed separately)

        address pauseGuardian = vm.envOr("PAUSE_GUARDIAN", TEMP_PAUSE_GUARDIAN);
        uint256 timelockDelay = vm.envOr("TIMELOCK_DELAY", TIMELOCK_DELAY);

        // ── Pre-flight checks ──
        require(coreAddress != address(0), "G7: AKMENA_CORE not set");
        require(boundaryAddress != address(0), "G7: AKMENA_BOUNDARY not set");
        require(safeAddress != address(0), "G7: SAFE_ADDRESS not set");

        bool isTemporary = (pauseGuardian == TEMP_PAUSE_GUARDIAN);
        if (isTemporary) {
            console.log("!!! TEMPORARY CONFIGURATION !!!");
            console.log("Pause guardian is the TEMPORARY address.");
            console.log("Do NOT use for production. See G7_SIGNER_ROTATION.md");
        }

        AkmenaCore core = AkmenaCore(coreAddress);
        AkmenaPolicyBoundary boundary = AkmenaPolicyBoundary(boundaryAddress);

        // Verify deployer is the broadcaster (only deployer can configure)
        require(core.deployer() == msg.sender, "G7: broadcaster must be deployer");

        vm.startBroadcast();

        // ── 1. Deploy TimelockController ──
        // Proposers: Safe (can schedule). Executors: Safe (can execute after delay).
        // Admin: address(0) — no admin, fully decentralized.
        address[] memory proposers = new address[](1);
        proposers[0] = safeAddress;
        address[] memory executors = new address[](1);
        executors[0] = safeAddress;

        TimelockController timelock = new TimelockController(
            timelockDelay,
            proposers,
            executors,
            msg.sender // deployer is initial admin, will renounce
        );
        console.log("TimelockController deployed at:", address(timelock));
        console.log("Timelock delay:", timelockDelay);

        // Renounce admin — timelock is now fully controlled by Safe via delay
        timelock.renounceRole(timelock.DEFAULT_ADMIN_ROLE(), msg.sender);
        console.log("Timelock admin renounced");

        // ── 2. Configure pause guardian ──
        core.setPauseGuardian(pauseGuardian);
        console.log("Pause guardian set to:", pauseGuardian);

        // ── 3. Transfer allowlistAdmin to timelock (slow adds) ──
        boundary.setAllowlistAdmin(address(timelock));
        console.log("allowlistAdmin -> timelock");

        // ── 4. Transfer emergencyAdmin to Safe (fast remove-only) ──
        boundary.setEmergencyAdmin(safeAddress);
        console.log("emergencyAdmin -> Safe:", safeAddress);

        // ── 5. Propose deployer transfer to timelock ──
        // The timelock must accept via acceptDeployer() after 24h delay
        core.proposeDeployer(address(timelock));
        console.log("Deployer transfer proposed to timelock");
        console.log("Timelock must call acceptDeployer() after scheduling via Safe");

        vm.stopBroadcast();

        // ── Post-deployment verification checklist ──
        console.log("");
        console.log("=== G-7 VERIFICATION CHECKLIST ===");
        console.log("1. Timelock delay is 24h:", timelock.getMinDelay() == 24 hours);
        console.log("2. Safe is proposer:", timelock.hasRole(timelock.PROPOSER_ROLE(), safeAddress));
        console.log("3. Safe is executor:", timelock.hasRole(timelock.EXECUTOR_ROLE(), safeAddress));
        console.log("4. Pause guardian:", core.pauseGuardian());
        console.log("5. Pending deployer:", core.pendingDeployer());
        console.log("");
        if (isTemporary) {
            console.log("!!! REMINDER: Temporary configuration active.");
            console.log("!!! Run signer rotation before production. See G7_SIGNER_ROTATION.md");
        }
    }
}
