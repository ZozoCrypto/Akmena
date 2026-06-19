// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IAgentRegistry {
    struct Agent {
        bytes32 id;
        address owner;
        uint64 createdAt;
        uint64 updatedAt;
        uint32 version;
        bool active;
        bool verified;
        string metadataURI;
    }

    function register(bytes32 id, string calldata metadataURI) external;

    function exists(bytes32 id) external view returns (bool);

    function totalAgents() external view returns (uint256);

    function agentOf(address owner) external view returns (bytes32);

    function getAgent(bytes32 id) external view returns (Agent memory);
}
