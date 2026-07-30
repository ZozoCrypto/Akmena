// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IDiscoveryEngine} from "./IDiscoveryEngine.sol";
import {LibStorage} from "../storage/LibStorage.sol";

contract DiscoveryEngine is IDiscoveryEngine {
    function registerProfile(bytes32 category, string calldata metadataURI) external override {
        if (category == bytes32(0)) revert EmptyCategory();

        LibStorage.DiscoveryStorage storage ds = LibStorage.discovery();
        ds.agentProfiles[msg.sender] = LibStorage.DiscoveryData({
            category: category,
            metadataURI: metadataURI,
            isActive: true
        });

        emit AgentRegistered(msg.sender, category, metadataURI);
    }

    function updateStatus(bool isActive) external override {
        LibStorage.DiscoveryStorage storage ds = LibStorage.discovery();
        ds.agentProfiles[msg.sender].isActive = isActive;
        
        emit AgentStatusUpdated(msg.sender, isActive);
    }

    function getProfile(address agent) external view override returns (LibStorage.DiscoveryData memory) {
        return LibStorage.discovery().agentProfiles[agent];
    }
}
