import { describe, expect, it } from 'vitest';
import { EscrowEngineABI } from '../src/abis/EscrowEngine';
import { PaymentsEngineABI } from '../src/abis/PaymentsEngine';
import { WorkflowEngineABI } from '../src/abis/WorkflowEngine';
import { EconomicCommitmentEngineABI } from '../src/abis/EconomicCommitmentEngine';
import { IdentityFactoryABI } from '../src/abis/IdentityFactory';
import { IdentityABI } from '../src/abis/Identity';
import { RegistryABI } from '../src/abis/Registry';
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
        const createEscrowOverloads = EscrowEngineABI.filter(
            (entry) =>
                entry.type === 'function' && entry.name === 'createEscrow',
        );

        expect(createEscrowOverloads).toHaveLength(4);

        const createEscrowInputTypes = createEscrowOverloads
            .map((entry: any) => entry.inputs.map((input: any) => input.type))
            .sort((a: string[], b: string[]) => a.join(',').localeCompare(b.join(',')));

        expect(createEscrowInputTypes).toEqual([
            ['address', 'address', 'address', 'uint256'],
            ['address', 'address', 'address', 'uint256', 'bytes32'],
            ['address', 'address', 'uint256'],
            ['address', 'address', 'uint256', 'bytes32'],
        ]);

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

    it('matches the canonical Identity API', () => {
        expect(inputTypes(IdentityFactoryABI, 'createIdentity')).toEqual([
            'uint8',
            'string',
        ]);

        expect(inputTypes(IdentityABI, 'updateMetadata')).toEqual([
            'string',
        ]);

        expect(inputTypes(IdentityABI, 'transferOwnership')).toEqual([
            'address',
        ]);

        expect(inputTypes(RegistryABI, 'identityAddress')).toEqual([
            'uint256',
        ]);

        expect(inputTypes(RegistryABI, 'identityId')).toEqual([
            'address',
        ]);

        expect(inputTypes(RegistryABI, 'exists')).toEqual([
            'uint256',
        ]);
    });
});
