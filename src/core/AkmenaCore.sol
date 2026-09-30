// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {LibStorage} from "../storage/LibStorage.sol";

/// @title AkmenaCore
/// @notice Central protocol registry and module discovery layer.
/// @dev Upper protocol layers depend on Core. Core knows nothing about them.
contract AkmenaCore {
    string public constant PROTOCOL_VERSION = "2.0.0";

    address public immutable deployer;

    bool private paused;

    /// @notice Pause guardian (spec §7.1).
    /// @dev Narrowly scoped: may pause execution immediately (containment is
    /// fail-closed) but may NEVER unpause. Unpause is deployer-only (which
    /// becomes the timelock after the G-7 migration). Set to address(0) to
    /// disable the guardian role.
    address public pauseGuardian;

    event ModuleRegistered(bytes32 indexed moduleKey, address indexed moduleAddress, string version);

    event ModuleEnabled(bytes32 indexed moduleKey, bool status);

    event PauseStatusChanged(bool paused);

    /// @notice Emitted when the pause guardian changes.
    event PauseGuardianUpdated(address indexed guardian);

    error UnauthorizedAccess();
    error InvalidModuleAddress();
    error ModuleAlreadyRegistered();

    modifier onlyDeployer() {
        if (msg.sender != deployer) {
            revert UnauthorizedAccess();
        }
        _;
    }

    constructor() {
        deployer = msg.sender;
    }

    function registerModule(bytes32 key, address moduleAddress, string calldata version) external onlyDeployer {
        if (moduleAddress == address(0)) {
            revert InvalidModuleAddress();
        }

        LibStorage.RegistryStorage storage ds = LibStorage.registry();

        if (ds.modules[key] != address(0)) {
            revert ModuleAlreadyRegistered();
        }

        ds.modules[key] = moduleAddress;
        ds.enabled[key] = true;
        ds.version[key] = version;

        emit ModuleRegistered(key, moduleAddress, version);

        emit ModuleEnabled(key, true);
    }

    function setModuleStatus(bytes32 key, bool status) external onlyDeployer {
        LibStorage.RegistryStorage storage ds = LibStorage.registry();

        ds.enabled[key] = status;

        emit ModuleEnabled(key, status);
    }

    function setPaused(bool status) external {
        if (status) {
            // Pause (containment): guardian or deployer, immediate.
            // Fail-closed by design — pausing can only deny service.
            if (msg.sender != pauseGuardian && msg.sender != deployer) {
                revert UnauthorizedAccess();
            }
        } else {
            // Unpause: deployer ONLY. A compromised guardian must not be
            // able to silently resume execution (spec §7.1).
            if (msg.sender != deployer) {
                revert UnauthorizedAccess();
            }
        }
        paused = status;

        emit PauseStatusChanged(status);
    }

    /// @notice Set or rotate the pause guardian. Deployer-only.
    /// @dev Set to address(0) to disable the guardian role entirely.
    // forge-lint: disable-next-line(missing-zero-check)
    // Justification: address(0) is the defined "disable guardian" value.
    function setPauseGuardian(address guardian_) external onlyDeployer {
        pauseGuardian = guardian_;
        emit PauseGuardianUpdated(guardian_);
    }

    function isPaused() external view returns (bool) {
        return paused;
    }

    function getModule(bytes32 key)
        external
        view
        returns (address moduleAddress, bool isEnabled, string memory version)
    {
        LibStorage.RegistryStorage storage ds = LibStorage.registry();

        return (ds.modules[key], ds.enabled[key], ds.version[key]);
    }
}
