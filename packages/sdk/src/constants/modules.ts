import { keccak256, toHex } from 'viem';

export const MODULE_KEYS = {
    workflow: keccak256(toHex('akmena.module.workflow')),
    settlement: keccak256(toHex('akmena.module.settlement')),
    escrow: keccak256(toHex('akmena.module.escrow')),
    payments: keccak256(toHex('akmena.module.payments')),
    reputation: keccak256(toHex('akmena.module.reputation')),
    memory: keccak256(toHex('akmena.module.memory')),
    marketplace: keccak256(toHex('akmena.module.marketplace')),
    identity: keccak256(toHex('akmena.module.identity')),
} as const;

export type ModuleName = keyof typeof MODULE_KEYS;
