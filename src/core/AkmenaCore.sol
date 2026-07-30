// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {LibStorage} from "../storage/LibStorage.sol";

/// @title AkmenaCore
/// @notice The centralized hub for the Akmena Protocol V2.
/// @dev Registers and routes to isolated engine modules.
contract AkmenaCore {
    address public immutable deployer;

    event ModuleRegistered(bytes32 indexed moduleKey, address indexed moduleAddress);
    event ModuleEnabled(bytes32 indexed moduleKey, bool status);

    error UnauthorizedAccess();
    error InvalidModuleAddress();
    error ModuleAlreadyRegistered();

    modifier onlyDeployer() {
        if (msg.sender != deployer) revert UnauthorizedAccess();
        _;
    }

    constructor() {
        deployer = msg.sender;
    }

    /// @notice Registers an engine module into the protocol registry.
    function registerModule(bytes32 key, address moduleAddress, string calldata version) external onlyDeployer {
        if (moduleAddress == address(0)) revert InvalidModuleAddress();

        LibStorage.RegistryStorage storage ds = LibStorage.registry();
        if (ds.modules[key] != address(0)) revert ModuleAlreadyRegistered();

        ds.modules[key] = moduleAddress;
        ds.enabled[key] = true;
        ds.version[key] = version;

        emit ModuleRegistered(key, moduleAddress);
        emit ModuleEnabled(key, true);
    }

    /// @notice Updates the enabled status of an existing module.
    function setModuleStatus(bytes32 key, bool status) external onlyDeployer {
        LibStorage.RegistryStorage storage ds = LibStorage.registry();
        ds.enabled[key] = status;
        emit ModuleEnabled(key, status);
    }

    /// @notice View function to get module details.
    function getModule(bytes32 key) external view returns (address moduleAddress, bool isEnabled, string memory version) {
        LibStorage.RegistryStorage storage ds = LibStorage.registry();
        return (ds.modules[key], ds.enabled[key], ds.version[key]);
    }
}
