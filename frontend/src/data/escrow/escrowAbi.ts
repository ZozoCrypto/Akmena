import type { Abi } from 'viem';

export const ESCROW_ABI = [
  {
    type: 'function',
    name: 'asset',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'address' }],
  },
  {
    type: 'function',
    name: 'totalLocked',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'uint256' }],
  },
  {
    type: 'function',
    name: 'getEscrow',
    stateMutability: 'view',
    inputs: [{ name: 'escrowId', type: 'uint256' }],
    outputs: [
      {
        name: '',
        type: 'tuple',
        components: [
          { name: 'buyer', type: 'address' },
          { name: 'seller', type: 'address' },
          { name: 'amount', type: 'uint256' },
          { name: 'asset', type: 'address' },
          { name: 'status', type: 'uint8' },
        ],
      },
    ],
  },
  {
    type: 'event',
    name: 'EscrowCreated',
    anonymous: false,
    inputs: [
      {
        indexed: true,
        name: 'escrowId',
        type: 'uint256',
      },
      {
        indexed: true,
        name: 'buyer',
        type: 'address',
      },
      {
        indexed: true,
        name: 'seller',
        type: 'address',
      },
      {
        indexed: false,
        name: 'amount',
        type: 'uint256',
      },
    ],
  },
  {
    type: 'event',
    name: 'EscrowReleased',
    anonymous: false,
    inputs: [
      {
        indexed: true,
        name: 'escrowId',
        type: 'uint256',
      },
    ],
  },
  {
    type: 'event',
    name: 'EscrowRefunded',
    anonymous: false,
    inputs: [
      {
        indexed: true,
        name: 'escrowId',
        type: 'uint256',
      },
    ],
  },
] as const satisfies Abi;

export const ERC20_METADATA_ABI = [
  {
    type: 'function',
    name: 'symbol',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'string' }],
  },
  {
    type: 'function',
    name: 'decimals',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'uint8' }],
  },
] as const satisfies Abi;
