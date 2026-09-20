import { describe, expect, it } from 'vitest';
import { EscrowEngineABI } from '../src/abis/EscrowEngine';
import { PaymentsEngineABI } from '../src/abis/PaymentsEngine';
import { WorkflowEngineABI } from '../src/abis/WorkflowEngine';
import { EconomicCommitmentEngineABI } from '../src/abis/EconomicCommitmentEngine';
import { AgentRegistryABI } from '../src/abis/AgentRegistry';
import { MarketplaceEngineABI } from '../src/abis/MarketplaceEngine';

function findFunction(abi: readonly any[], name: string) {
    const item = abi.find(
        (entry) => entry.type === 'function' && entry.name === name,
    );

    expect(item).toBeDefined();
    return item;
}

function inputTypes(abi: readonly any[], name: string): string[] {
    return findFunction(abi, name).inputs.map((input: any) => input.type);
}

describe('Akmena ABI compatibility', () => {
    it('matches the canonical Escrow API', () => {
        expect(inputTypes(EscrowEngineABI, 'createEscrow')).toContain(
            'address',
        );
        expect(
            EscrowEngineABI.filter(
                (entry) =>
                    entry.type === 'function' && entry.name === 'createEscrow',
            ),
        ).toHaveLength(2);

        expect(inputTypes(EscrowEngineABI, 'releaseEscrow')).toEqual([
            'uint256',
        ]);
        expect(inputTypes(EscrowEngineABI, 'refundEscrow')).toEqual([
            'uint256',
        ]);
        expect(inputTypes(EscrowEngineABI, 'getEscrow')).toEqual([
            'uint256',
        ]);
    });

    it('matches the canonical Payments API', () => {
        expect(inputTypes(PaymentsEngineABI, 'executePayment')).toEqual([
            'address',
            'address',
            'uint256',
        ]);

        expect(inputTypes(PaymentsEngineABI, 'getTotalVolume')).toEqual([]);
    });

    it('matches the canonical Workflow API', () => {
        expect(inputTypes(WorkflowEngineABI, 'initializeWorkflow')).toEqual([
            'uint256',
            'bytes32',
            'bytes32',
        ]);

        expect(
            inputTypes(WorkflowEngineABI, 'advanceToCompletion'),
        ).toEqual(['bytes32', 'bytes', 'bytes', 'bytes']);
    });

    it('matches the canonical economic commitment settlement API', () => {
        const finalizeSettlement = findFunction(
            EconomicCommitmentEngineABI,
            'finalizeSettlement',
        );

        expect(
            finalizeSettlement.inputs.map((input: any) => input.type),
        ).toEqual(['uint256', 'bytes32']);

        const executeSettlement = EconomicCommitmentEngineABI.find(
            (entry) =>
                entry.type === 'function' &&
                entry.name === 'executeSettlement',
        );

        expect(executeSettlement).toBeUndefined();
    });

    it('matches the canonical Marketplace API', () => {
        expect(inputTypes(MarketplaceEngineABI, 'createTask')).toEqual([
            'uint256',
        ]);

        expect(inputTypes(MarketplaceEngineABI, 'assignTask')).toEqual([
            'uint256',
            'address',
        ]);

        expect(inputTypes(MarketplaceEngineABI, 'completeTask')).toEqual([
            'uint256',
            'address',
        ]);

        expect(inputTypes(MarketplaceEngineABI, 'getTask')).toEqual([
            'uint256',
        ]);
    });

    it('matches the canonical AgentRegistry API', () => {
        expect(inputTypes(AgentRegistryABI, 'register')).toEqual([
            'bytes32',
            'string',
        ]);

        expect(inputTypes(AgentRegistryABI, 'updateMetadata')).toEqual([
            'bytes32',
            'string',
        ]);
    });
});
