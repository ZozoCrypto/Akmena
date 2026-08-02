"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.EscrowEngineABI = void 0;
exports.EscrowEngineABI = [
    {
        "type": "function",
        "name": "createEscrow",
        "inputs": [
            {
                "name": "escrowId",
                "type": "bytes32",
                "internalType": "bytes32"
            },
            {
                "name": "payee",
                "type": "address",
                "internalType": "address"
            }
        ],
        "outputs": [],
        "stateMutability": "payable"
    },
    {
        "type": "function",
        "name": "exists",
        "inputs": [
            {
                "name": "escrowId",
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
        "name": "getEscrow",
        "inputs": [
            {
                "name": "escrowId",
                "type": "bytes32",
                "internalType": "bytes32"
            }
        ],
        "outputs": [
            {
                "name": "",
                "type": "tuple",
                "internalType": "struct IEscrowEngine.Escrow",
                "components": [
                    {
                        "name": "id",
                        "type": "bytes32",
                        "internalType": "bytes32"
                    },
                    {
                        "name": "payer",
                        "type": "address",
                        "internalType": "address"
                    },
                    {
                        "name": "payee",
                        "type": "address",
                        "internalType": "address"
                    },
                    {
                        "name": "amount",
                        "type": "uint256",
                        "internalType": "uint256"
                    },
                    {
                        "name": "released",
                        "type": "bool",
                        "internalType": "bool"
                    },
                    {
                        "name": "refunded",
                        "type": "bool",
                        "internalType": "bool"
                    }
                ]
            }
        ],
        "stateMutability": "view"
    },
    {
        "type": "function",
        "name": "refund",
        "inputs": [
            {
                "name": "escrowId",
                "type": "bytes32",
                "internalType": "bytes32"
            }
        ],
        "outputs": [],
        "stateMutability": "nonpayable"
    },
    {
        "type": "function",
        "name": "release",
        "inputs": [
            {
                "name": "escrowId",
                "type": "bytes32",
                "internalType": "bytes32"
            }
        ],
        "outputs": [],
        "stateMutability": "nonpayable"
    },
    {
        "type": "event",
        "name": "EscrowCreated",
        "inputs": [
            {
                "name": "escrowId",
                "type": "bytes32",
                "indexed": true,
                "internalType": "bytes32"
            },
            {
                "name": "payer",
                "type": "address",
                "indexed": true,
                "internalType": "address"
            },
            {
                "name": "payee",
                "type": "address",
                "indexed": true,
                "internalType": "address"
            },
            {
                "name": "amount",
                "type": "uint256",
                "indexed": false,
                "internalType": "uint256"
            }
        ],
        "anonymous": false
    },
    {
        "type": "event",
        "name": "EscrowRefunded",
        "inputs": [
            {
                "name": "escrowId",
                "type": "bytes32",
                "indexed": true,
                "internalType": "bytes32"
            }
        ],
        "anonymous": false
    },
    {
        "type": "event",
        "name": "EscrowReleased",
        "inputs": [
            {
                "name": "escrowId",
                "type": "bytes32",
                "indexed": true,
                "internalType": "bytes32"
            }
        ],
        "anonymous": false
    },
    {
        "type": "error",
        "name": "EscrowAlreadyExists",
        "inputs": []
    },
    {
        "type": "error",
        "name": "EscrowAlreadyRefunded",
        "inputs": []
    },
    {
        "type": "error",
        "name": "EscrowAlreadyReleased",
        "inputs": []
    },
    {
        "type": "error",
        "name": "EscrowNotFound",
        "inputs": []
    },
    {
        "type": "error",
        "name": "InvalidAmount",
        "inputs": []
    },
    {
        "type": "error",
        "name": "InvalidPayee",
        "inputs": []
    }
];
//# sourceMappingURL=EscrowEngine.js.map