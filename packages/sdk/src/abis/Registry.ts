// AUTO-GENERATED FROM FOUNDRY ARTIFACT
// Source: /home/cryptozozo/projects/akmena/out/Registry.sol/Registry.json
// DO NOT EDIT MANUALLY.

export const RegistryABI = [
  {
    "type": "constructor",
    "inputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "allocateIdentityId",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "bindIdentityFactory",
    "inputs": [
      {
        "name": "factory",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "exists",
    "inputs": [
      {
        "name": "id",
        "type": "uint256",
        "internalType": "uint256"
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
    "name": "factoryBinder",
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
    "name": "identityAddress",
    "inputs": [
      {
        "name": "id",
        "type": "uint256",
        "internalType": "uint256"
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
    "name": "identityFactory",
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
    "name": "identityId",
    "inputs": [
      {
        "name": "identity",
        "type": "address",
        "internalType": "address"
      }
    ],
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
    "name": "nextIdentityId",
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
    "name": "registerIdentity",
    "inputs": [
      {
        "name": "identity",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "event",
    "name": "IdentityRegistered",
    "inputs": [
      {
        "name": "identityId",
        "type": "uint256",
        "indexed": true,
        "internalType": "uint256"
      },
      {
        "name": "identity",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "identityType",
        "type": "uint8",
        "indexed": false,
        "internalType": "enum IIdentity.IdentityType"
      }
    ],
    "anonymous": false
  },
  {
    "type": "error",
    "name": "FactoryAlreadyBound",
    "inputs": []
  },
  {
    "type": "error",
    "name": "IdentityAlreadyRegistered",
    "inputs": []
  },
  {
    "type": "error",
    "name": "IdentityNotFound",
    "inputs": []
  },
  {
    "type": "error",
    "name": "InvalidFactory",
    "inputs": []
  },
  {
    "type": "error",
    "name": "InvalidIdentity",
    "inputs": []
  },
  {
    "type": "error",
    "name": "InvalidIdentityId",
    "inputs": []
  },
  {
    "type": "error",
    "name": "UnauthorizedBinder",
    "inputs": []
  },
  {
    "type": "error",
    "name": "UnauthorizedFactory",
    "inputs": []
  }
] as const;
