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

    event ModuleRegistered(
        bytes32 indexed moduleKey,
        address indexed moduleAddress,
        string version
    );

    event ModuleEnabled(
        bytes32 indexed moduleKey,
        bool status
    );

    event PauseStatusChanged(
        bool paused
    );

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

    function registerModule(
        bytes32 key,
        address moduleAddress,
        string calldata version
    )
        external
        onlyDeployer
    {
        if(moduleAddress == address(0)) {
            revert InvalidModuleAddress();
        }

        LibStorage.RegistryStorage storage ds =
            LibStorage.registry();

        if(ds.modules[key] != address(0)) {
            revert ModuleAlreadyRegistered();
        }

        ds.modules[key] = moduleAddress;
        ds.enabled[key] = true;
        ds.version[key] = version;

        emit ModuleRegistered(
            key,
            moduleAddress,
            version
        );

        emit ModuleEnabled(
            key,
            true
        );
    }

    function setModuleStatus(
        bytes32 key,
        bool status
    )
        external
        onlyDeployer
    {
        LibStorage.RegistryStorage storage ds =
            LibStorage.registry();

        ds.enabled[key] = status;

        emit ModuleEnabled(
            key,
            status
        );
    }

    function setPaused(
        bool status
    )
        external
        onlyDeployer
    {
        paused = status;

        emit PauseStatusChanged(status);
    }

    function isPaused()
        external
        view
        returns(bool)
    {
        return paused;
    }

    function getModule(
        bytes32 key
    )
        external
        view
        returns(
            address moduleAddress,
            bool isEnabled,
            string memory version
        )
    {
        LibStorage.RegistryStorage storage ds =
            LibStorage.registry();

        return(
            ds.modules[key],
            ds.enabled[key],
            ds.version[key]
        );
    }
}
