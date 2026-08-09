// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AkmenaCore} from "../../../src/core/AkmenaCore.sol";

contract CoreRouterHandler {
    AkmenaCore public core;

    bytes32[] public registeredKeys;
    mapping(bytes32 => bool) public isRegistered;

    constructor(AkmenaCore _core) {
        core = _core;
    }

    function registerModule(
        bytes32 key,
        address module,
        string calldata version
    ) public {
        if (module == address(0)) return;

        try core.registerModule(key, module, version) {
            if (!isRegistered[key]) {
                registeredKeys.push(key);
                isRegistered[key] = true;
            }
        } catch {}
    }

    function toggleModule(
        bytes32 key,
        bool enabled
    ) public {
        try core.setModuleStatus(key, enabled) {
        } catch {}
    }

    function pause(bool state) public {
        try core.setPaused(state) {
        } catch {}
    }

    function registeredKeysLength() external view returns (uint256) {
        return registeredKeys.length;
    }
}
