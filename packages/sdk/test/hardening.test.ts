import { describe, expect, it } from 'vitest';
import { base } from 'viem/chains';
import { AkmenaClient } from '../src/client/AkmenaClient';
import {
    AkmenaError,
    WalletRequiredError,
    translateContractError,
} from '../src/errors';

describe('SDK hardening', () => {
    it('preserves RPC configuration when binding a wallet', async () => {
        const client = new AkmenaClient({
            coreAddress: '0x1234567890123456789012345678901234567890',
            chain: base,
            rpcUrl: 'http://127.0.0.1:8545',
        });

        const wallet = {
            account: {
                address: '0x1111111111111111111111111111111111111111',
            },
        } as never;

        const bound = client.withWallet(wallet);

        expect(bound.walletClient).toBeDefined();
        expect(bound.coreAddress).toBe(client.coreAddress);
    });

    it('exposes WalletRequiredError as an AkmenaError', () => {
        const error = new WalletRequiredError();

        expect(error).toBeInstanceOf(AkmenaError);
        expect(error.code).toBe('WALLET_REQUIRED');
    });

    it('keeps unknown contract errors typed', () => {
        try {
            translateContractError({
                message: 'Unknown protocol failure',
            });
            throw new Error('expected throw');
        } catch (error) {
            expect(error).toBeInstanceOf(AkmenaError);
        }
    });
});
