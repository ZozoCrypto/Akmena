// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {LibStorage} from "../storage/LibStorage.sol";

interface IDiscoveryEngine {
    event AgentRegistered(address indexed agent, bytes32 indexed category, string metadataURI);
    event AgentStatusUpdated(address indexed agent, bool isActive);

    error EmptyCategory();

    function registerProfile(bytes32 category, string calldata metadataURI) external;
    function updateStatus(bool isActive) external;
    function getProfile(address agent) external view returns (LibStorage.DiscoveryData memory);
}
