import { describe, it, expect } from 'vitest';
import { AkmenaClient } from '../src/client/AkmenaClient';
import { MODULE_KEYS } from '../src/constants/modules';

describe('AkmenaClient Architecture', () => {
    it('initializes cleanly in read-only mode', () => {
        const client = new AkmenaClient({ coreAddress: '0x1234567890123456789012345678901234567890' });
        expect(client.coreAddress).toBe('0x1234567890123456789012345678901234567890');
        expect(client.walletClient).toBeUndefined();
        expect(client.workflow).toBeDefined();
    });

    it('has accurate canonical module keys', () => {
        expect(MODULE_KEYS.workflow).toBeDefined();
        expect(MODULE_KEYS.settlement).toBeDefined();
    });
});
