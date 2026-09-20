import { encodeErrorResult } from 'viem';

import { describe, expect, it } from 'vitest';
import {
    AkmenaError,
    AuthorizationError,
    CapabilityError,
    ModuleUnavailableError,
    UnsupportedProtocolVersionError,
    WalletRequiredError,
    WorkflowError,
    translateContractError,
} from '../src/errors';
import { EconomicCommitmentEngineABI } from '../src/abis/EconomicCommitmentEngine';
import { MarketplaceEngineABI } from '../src/abis/MarketplaceEngine';

describe('Akmena SDK errors', () => {
    it('decodes EconomicCommitmentEngine custom errors', () => {
        const data = encodeErrorResult({
            abi: EconomicCommitmentEngineABI,
            errorName: 'CommitmentNotFound',
        });

        expect(() => {
            translateContractError({ data });
        }).toThrowError(
            expect.objectContaining({
                code: 'CommitmentNotFound',
            }),
        );
    });

    it('decodes MarketplaceEngine authorization errors', () => {
        const data = encodeErrorResult({
            abi: MarketplaceEngineABI,
            errorName: 'UnauthorizedAccess',
        });

        expect(() => {
            translateContractError({ data });
        }).toThrowError(
            expect.objectContaining({
                code: 'UNAUTHORIZED',
            }),
        );
    });

    it('creates a typed wallet-required error', () => {
        const error = new WalletRequiredError();

        expect(error).toBeInstanceOf(AkmenaError);
        expect(error.code).toBe('WALLET_REQUIRED');
        expect(error.message).toContain('connected wallet');
    });

    it('preserves typed protocol error codes', () => {
        expect(new AuthorizationError().code).toBe('UNAUTHORIZED');
        expect(new CapabilityError().code).toBe('CAPABILITY_MISSING');
        expect(new WorkflowError().code).toBe('INVALID_WORKFLOW_STATE');

        expect(new ModuleUnavailableError('escrow').code).toBe(
            'MODULE_UNAVAILABLE',
        );

        expect(
            new UnsupportedProtocolVersionError('2.x', '1.0.0').code,
        ).toBe('UNSUPPORTED_VERSION');
    });

    it('translates common authorization reverts', () => {
        expect(() =>
            translateContractError({
                message: 'UnauthorizedInitiator',
            }),
        ).toThrowError(AuthorizationError);
    });

    it('translates common workflow reverts', () => {
        expect(() =>
            translateContractError({
                message: 'InvalidWorkflowState',
            }),
        ).toThrowError(WorkflowError);
    });

    it('normalizes unknown contract reverts', () => {
        try {
            translateContractError({
                message: 'Something unexpected happened',
            });
            throw new Error('Expected translateContractError to throw');
        } catch (error) {
            expect(error).toBeInstanceOf(AkmenaError);
            expect((error as AkmenaError).code).toBe('CONTRACT_REVERT');
        }
    });
});
