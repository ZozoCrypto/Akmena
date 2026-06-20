// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title Akmena Agent Registry
/// @notice Canonical registry of protocol agents.
contract AgentRegistry {
    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    error Unauthorized();
    error AgentNotFound();
    error AgentAlreadyExists();
    error OwnerAlreadyRegistered();
    error ZeroAddress();
    error InvalidMetadata();

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    event RegistryInitialized(address indexed owner);

    event AgentRegistered(bytes32 indexed id, address indexed owner, string metadataURI);

    event MetadataUpdated(bytes32 indexed id, string metadataURI, uint32 version);

    event VerificationUpdated(bytes32 indexed id, bool verified);

    // -------------------------------------------------------------------------
    // Storage
    // -------------------------------------------------------------------------

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

    address public immutable registryOwner;

    mapping(bytes32 => Agent) internal agents;
    mapping(address => bytes32) internal ownerToAgent;

    uint256 internal agentCount;

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    constructor() {
        registryOwner = msg.sender;

        emit RegistryInitialized(msg.sender);
    }

    // -------------------------------------------------------------------------
    // Registration
    // -------------------------------------------------------------------------

    function register(bytes32 id, string calldata metadataURI) external {
        if (msg.sender == address(0)) {
            revert ZeroAddress();
        }

        if (bytes(metadataURI).length == 0) {
            revert InvalidMetadata();
        }

        if (exists(id)) {
            revert AgentAlreadyExists();
        }

        if (ownerToAgent[msg.sender] != bytes32(0)) {
            revert OwnerAlreadyRegistered();
        }

        agents[id] = Agent({
            id: id,
            owner: msg.sender,
            createdAt: uint64(block.timestamp),
            updatedAt: uint64(block.timestamp),
            version: 1,
            active: true,
            verified: false,
            metadataURI: metadataURI
        });

        ownerToAgent[msg.sender] = id;

        unchecked {
            agentCount++;
        }

        emit AgentRegistered(id, msg.sender, metadataURI);
    }

    // -------------------------------------------------------------------------
    // Metadata
    // -------------------------------------------------------------------------

    function updateMetadata(bytes32 id, string calldata metadataURI) external {
        if (!exists(id)) {
            revert AgentNotFound();
        }

        if (bytes(metadataURI).length == 0) {
            revert InvalidMetadata();
        }

        Agent storage agent = agents[id];

        if (agent.owner != msg.sender) {
            revert Unauthorized();
        }

        agent.metadataURI = metadataURI;
        agent.updatedAt = uint64(block.timestamp);
        agent.version++;

        emit MetadataUpdated(id, metadataURI, agent.version);
    }

    // -------------------------------------------------------------------------
    // Verification
    // -------------------------------------------------------------------------

    function setVerification(bytes32 id, bool verified) external {
        if (!exists(id)) {
            revert AgentNotFound();
        }

        if (msg.sender != registryOwner) {
            revert Unauthorized();
        }

        Agent storage agent = agents[id];

        agent.verified = verified;
        agent.updatedAt = uint64(block.timestamp);

        emit VerificationUpdated(id, verified);
    }

    // -------------------------------------------------------------------------
    // Views
    // -------------------------------------------------------------------------

    function totalAgents() external view returns (uint256) {
        return agentCount;
    }

    function exists(bytes32 id) public view returns (bool) {
        return agents[id].owner != address(0);
    }

    function agentOf(address owner) external view returns (bytes32) {
        return ownerToAgent[owner];
    }

    function ownerOf(bytes32 id) external view returns (address) {
        if (!exists(id)) {
            revert AgentNotFound();
        }

        return agents[id].owner;
    }

    function isVerified(bytes32 id) external view returns (bool) {
        if (!exists(id)) {
            revert AgentNotFound();
        }

        return agents[id].verified;
    }

    function getAgent(bytes32 id) external view returns (Agent memory) {
        if (!exists(id)) {
            revert AgentNotFound();
        }

        return agents[id];
    }
}
