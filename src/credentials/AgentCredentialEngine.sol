// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../interfaces/IAgentCredentialEngine.sol";

contract AgentCredentialEngine is IAgentCredentialEngine {
    error EmptyCredential();

    mapping(bytes32 => Credential[]) internal credentials;
    mapping(bytes32 => mapping(bytes32 => bool)) internal credentialExists;

    function addCredential(bytes32 agentId, string calldata credential) external {
        if (bytes(credential).length == 0) {
            revert EmptyCredential();
        }

        bytes32 credentialHash = keccak256(bytes(credential));

        credentials[agentId].push(Credential({agentId: agentId, value: credential, issuedAt: block.timestamp}));

        credentialExists[agentId][credentialHash] = true;

        emit CredentialAdded(agentId, credential);
    }

    function getCredentials(bytes32 agentId) external view returns (Credential[] memory) {
        return credentials[agentId];
    }

    function hasCredential(bytes32 agentId, bytes32 credentialHash) external view returns (bool) {
        return credentialExists[agentId][credentialHash];
    }
}
