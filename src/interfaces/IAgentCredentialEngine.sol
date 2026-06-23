// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IAgentCredentialEngine {
    struct Credential {
        bytes32 agentId;
        string value;
        uint256 issuedAt;
    }

    event CredentialAdded(bytes32 indexed agentId, string credential);

    function addCredential(bytes32 agentId, string calldata credential) external;

    function getCredentials(bytes32 agentId) external view returns (Credential[] memory);

    function hasCredential(bytes32 agentId, bytes32 credentialHash) external view returns (bool);
}
