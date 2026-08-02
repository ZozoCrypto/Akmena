import { describe, it, expect } from 'vitest';
import { AkmenaClient } from '../src/client/AkmenaClient';
import { base } from 'viem/chains';
import { privateKeyToAccount } from 'viem/accounts';
import { createWalletClient, http } from 'viem';
import { MODULE_KEYS } from '../src/constants/modules';
import { AuthorizationError, translateContractError } from '../src/errors';

describe('Akmena SDK E2E & Integration Suite', () => {
    const mockCoreAddress = '0x1111111111111111111111111111111111111111';
    const testAccount = privateKeyToAccount('0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80');

    it('instantiates AkmenaClient and binds wallet correctly', () => {
        const client = new AkmenaClient({
            coreAddress: mockCoreAddress,
            chain: base,
            rpcUrl: 'http://127.0.0.1:8545'
        });

        const walletClient = createWalletClient({
            account: testAccount,
            chain: base,
            transport: http('http://127.0.0.1:8545')
        });

        const boundClient = client.withWallet(walletClient);
        expect(boundClient.walletClient).toBeDefined();
        expect(boundClient.walletClient?.account?.address).toBe(testAccount.address);
    });

    it('exposes all sovereign modules and valid bytes32 module keys', () => {
        const client = new AkmenaClient({
            coreAddress: mockCoreAddress,
            chain: base,
            rpcUrl: 'http://127.0.0.1:8545'
        });

        expect(client.agent).toBeDefined();
        expect(client.escrow).toBeDefined();
        expect(client.payments).toBeDefined();
        expect(client.workflow).toBeDefined();
        
        // Verify module keys are cryptographic bytes32 hashes
        expect(MODULE_KEYS.identity).toMatch(/^0x[a-fA-F0-9]{64}$/);
        expect(MODULE_KEYS.escrow).toMatch(/^0x[a-fA-F0-9]{64}$/);
    });

    it('translates contract errors deterministically using ABI decoding fallback', () => {
        const rawSimulatedError = {
            message: 'Execution reverted with reason: UnauthorizedInitiator'
        };

        expect(() => {
            translateContractError(rawSimulatedError);
        }).toThrow(AuthorizationError);
    });
});
