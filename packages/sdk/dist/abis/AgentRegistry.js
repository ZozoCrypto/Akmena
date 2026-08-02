"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.AgentRegistryABI = void 0;
exports.AgentRegistryABI = [
    {
        "type": "constructor",
        "inputs": [],
        "stateMutability": "nonpayable"
    },
    {
        "type": "function",
        "name": "agentOf",
        "inputs": [
            {
                "name": "owner",
                "type": "address",
                "internalType": "address"
            }
        ],
        "outputs": [
            {
                "name": "",
                "type": "bytes32",
                "internalType": "bytes32"
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "exists",
        "inputs": [
            {
                "name": "id",
                "type": "bytes32",
                "internalType": "bytes32"
            }
        ],
        "outputs": [
            {
                "name": "",
                "type": "bool",
                "internalType": "bool"
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "getAgent",
        "inputs": [
            {
                "name": "id",
                "type": "bytes32",
                "internalType": "bytes32"
            }
        ],
        "outputs": [
            {
                "name": "",
                "type": "tuple",
                "internalType": "struct AgentRegistry.Agent",
                "components": [
                    {
                        "name": "id",
                        "type": "bytes32",
                        "internalType": "bytes32"
                    },
                    {
                        "name": "owner",
                        "type": "address",
                        "internalType": "address"
                    },
                    {
                        "name": "createdAt",
                        "type": "uint64",
                        "internalType": "uint64"
                    },
                    {
                        "name": "updatedAt",
                        "type": "uint64",
                        "internalType": "uint64"
                    },
                    {
                        "name": "version",
                        "type": "uint32",
                        "internalType": "uint32"
                    },
                    {
                        "name": "active",
                        "type": "bool",
                        "internalType": "bool"
                    },
                    {
                        "name": "verified",
                        "type": "bool",
                        "internalType": "bool"
                    },
                    {
                        "name": "metadataURI",
                        "type": "string",
                        "internalType": "string"
                    }
                ]
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "isVerified",
        "inputs": [
            {
                "name": "id",
                "type": "bytes32",
                "internalType": "bytes32"
            }
        ],
        "outputs": [
            {
                "name": "",
                "type": "bool",
                "internalType": "bool"
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "ownerOf",
        "inputs": [
            {
                "name": "id",
                "type": "bytes32",
                "internalType": "bytes32"
            }
        ],
        "outputs": [
            {
                "name": "",
                "type": "address",
                "internalType": "address"
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "register",
        "inputs": [
            {
                "name": "id",
                "type": "bytes32",
                "internalType": "bytes32"
            },
            {
                "name": "metadataURI",
                "type": "string",
                "internalType": "string"
            }
        ],
        "outputs": [],
        "stateMutability": "nonpayable"
    },
    {
        "type": "function",
        "name": "registryOwner",
        "inputs": [],
        "outputs": [
            {
                "name": "",
                "type": "address",
                "internalType": "address"
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "setVerification",
        "inputs": [
            {
                "name": "id",
                "type": "bytes32",
                "internalType": "bytes32"
            },
            {
                "name": "verified",
                "type": "bool",
                "internalType": "bool"
            }
        ],
        "outputs": [],
        "stateMutability": "nonpayable"
    },
    {
        "type": "function",
        "name": "totalAgents",
        "inputs": [],
        "outputs": [
            {
                "name": "",
                "type": "uint256",
                "internalType": "uint256"
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "updateMetadata",
        "inputs": [
            {
                "name": "id",
                "type": "bytes32",
                "internalType": "bytes32"
            },
            {
                "name": "metadataURI",
                "type": "string",
                "internalType": "string"
            }
        ],
        "outputs": [],
        "stateMutability": "nonpayable"
    },
    {
        "type": "event",
        "name": "AgentRegistered",
        "inputs": [
            {
                "name": "id",
                "type": "bytes32",
                "indexed": true,
                "internalType": "bytes32"
            },
            {
                "name": "owner",
                "type": "address",
                "indexed": true,
                "internalType": "address"
            },
            {
                "name": "metadataURI",
                "type": "string",
                "indexed": false,
                "internalType": "string"
            }
        ],
        "anonymous": false
    },
    {
        "type": "event",
        "name": "MetadataUpdated",
        "inputs": [
            {
                "name": "id",
                "type": "bytes32",
                "indexed": true,
                "internalType": "bytes32"
            },
            {
                "name": "metadataURI",
                "type": "string",
                "indexed": false,
                "internalType": "string"
            },
            {
                "name": "version",
                "type": "uint32",
                "indexed": false,
                "internalType": "uint32"
            }
        ],
        "anonymous": false
    },
    {
        "type": "event",
        "name": "RegistryInitialized",
        "inputs": [
            {
                "name": "owner",
                "type": "address",
                "indexed": true,
                "internalType": "address"
            }
        ],
        "anonymous": false
    },
    {
        "type": "event",
        "name": "VerificationUpdated",
        "inputs": [
            {
                "name": "id",
                "type": "bytes32",
                "indexed": true,
                "internalType": "bytes32"
            },
            {
                "name": "verified",
                "type": "bool",
                "indexed": false,
                "internalType": "bool"
            }
        ],
        "anonymous": false
    },
    {
        "type": "error",
        "name": "AgentAlreadyExists",
        "inputs": []
    },
    {
        "type": "error",
        "name": "AgentNotFound",
        "inputs": []
    },
    {
        "type": "error",
        "name": "InvalidMetadata",
        "inputs": []
    },
    {
        "type": "error",
        "name": "OwnerAlreadyRegistered",
        "inputs": []
    },
    {
        "type": "error",
        "name": "Unauthorized",
        "inputs": []
    },
    {
        "type": "error",
        "name": "ZeroAddress",
        "inputs": []
    }
];
//# sourceMappingURL=AgentRegistry.js.map