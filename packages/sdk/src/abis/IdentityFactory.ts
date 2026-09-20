// AUTO-GENERATED FROM FOUNDRY ARTIFACT
// Source: /home/cryptozozo/projects/akmena/out/IdentityFactory.sol/IdentityFactory.json
// DO NOT EDIT MANUALLY.

export const IdentityFactoryABI = [
  {
    "type": "constructor",
    "inputs": [
      {
        "name": "implementation_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "registry_",
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "createIdentity",
    "inputs": [
      {
        "name": "identityType",
        "type": "uint8",
        "internalType": "enum IIdentity.IdentityType"
      },
      {
        "name": "metadataURI",
        "type": "string",
        "internalType": "string"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "implementation",
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
    "name": "registry",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "contract IRegistry"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "event",
    "name": "IdentityCreated",
    "inputs": [
      {
        "name": "clone",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "id",
        "type": "uint256",
        "indexed": true,
        "internalType": "uint256"
      },
      {
        "name": "identityType",
        "type": "uint8",
        "indexed": true,
        "internalType": "enum IIdentity.IdentityType"
      }
    ],
    "anonymous": false
  },
  {
    "type": "error",
    "name": "CloneCreationFailed",
    "inputs": []
  },
  {
    "type": "error",
    "name": "InvalidImplementation",
    "inputs": []
  },
  {
    "type": "error",
    "name": "InvalidRegistry",
    "inputs": []
  }
] as const;
