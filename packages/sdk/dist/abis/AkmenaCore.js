"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.AkmenaCoreABI = void 0;
exports.AkmenaCoreABI = [
    {
        "type": "constructor",
        "inputs": [],
        "stateMutability": "nonpayable"
    },
    {
        "type": "function",
        "name": "PROTOCOL_VERSION",
        "inputs": [],
        "outputs": [
            {
                "name": "",
                "type": "string",
                "internalType": "string"
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "deployer",
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
        "name": "getModule",
        "inputs": [
            {
                "name": "key",
                "type": "bytes32",
                "internalType": "bytes32"
            }
        ],
        "outputs": [
            {
                "name": "moduleAddress",
                "type": "address",
                "internalType": "address"
            },
            {
                "name": "isEnabled",
                "type": "bool",
                "internalType": "bool"
            },
            {
                "name": "version",
                "type": "string",
                "internalType": "string"
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "isPaused",
        "inputs": [],
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
        "name": "registerModule",
        "inputs": [
            {
                "name": "key",
                "type": "bytes32",
                "internalType": "bytes32"
            },
            {
                "name": "moduleAddress",
                "type": "address",
                "internalType": "address"
            },
            {
                "name": "version",
                "type": "string",
                "internalType": "string"
            }
        ],
        "outputs": [],
        "stateMutability": "nonpayable"
    },
    {
        "type": "function",
        "name": "setModuleStatus",
        "inputs": [
            {
                "name": "key",
                "type": "bytes32",
                "internalType": "bytes32"
            },
            {
                "name": "status",
                "type": "bool",
                "internalType": "bool"
            }
        ],
        "outputs": [],
        "stateMutability": "nonpayable"
    },
    {
        "type": "function",
        "name": "setPaused",
        "inputs": [
            {
                "name": "status",
                "type": "bool",
                "internalType": "bool"
            }
        ],
        "outputs": [],
        "stateMutability": "nonpayable"
    },
    {
        "type": "event",
        "name": "ModuleEnabled",
        "inputs": [
            {
                "name": "moduleKey",
                "type": "bytes32",
                "indexed": true,
                "internalType": "bytes32"
            },
            {
                "name": "status",
                "type": "bool",
                "indexed": false,
                "internalType": "bool"
            }
        ],
        "anonymous": false
    },
    {
        "type": "event",
        "name": "ModuleRegistered",
        "inputs": [
            {
                "name": "moduleKey",
                "type": "bytes32",
                "indexed": true,
                "internalType": "bytes32"
            },
            {
                "name": "moduleAddress",
                "type": "address",
                "indexed": true,
                "internalType": "address"
            },
            {
                "name": "version",
                "type": "string",
                "indexed": false,
                "internalType": "string"
            }
        ],
        "anonymous": false
    },
    {
        "type": "event",
        "name": "PauseStatusChanged",
        "inputs": [
            {
                "name": "paused",
                "type": "bool",
                "indexed": false,
                "internalType": "bool"
            }
        ],
        "anonymous": false
    },
    {
        "type": "error",
        "name": "InvalidModuleAddress",
        "inputs": []
    },
    {
        "type": "error",
        "name": "ModuleAlreadyRegistered",
        "inputs": []
    },
    {
        "type": "error",
        "name": "UnauthorizedAccess",
        "inputs": []
    }
];
//# sourceMappingURL=AkmenaCore.js.map