import { describe, it, expect } from 'vitest';
import { AkmenaClient } from '../src/client/AkmenaClient';
import { base } from 'viem/chains';
import { MODULE_KEYS } from '../src/constants/modules';

describe('AkmenaClient Architecture', () => {
    it('initializes cleanly in read-only mode', () => {
        const client = new AkmenaClient({
            coreAddress: '0x1234567890123456789012345678901234567890',
            chain: base,
            rpcUrl: 'https://mainnet.base.org'
        });
        expect(client).toBeDefined();
    });

    it('has accurate canonical module keys', () => {
        expect(MODULE_KEYS.identity).toBeDefined();
        expect(MODULE_KEYS.escrow).toBeDefined();
    });
});
