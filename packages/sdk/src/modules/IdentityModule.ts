import {
    decodeEventLog,
    WatchContractEventReturnType,
} from 'viem';
import { AkmenaClient } from '../client/AkmenaClient';
import { translateContractError, WalletRequiredError } from '../errors';
import { IdentityFactoryABI } from '../abis/IdentityFactory';
import { IdentityABI } from '../abis/Identity';
import { RegistryABI } from '../abis/Registry';

export type IdentityType = 0 | 1 | 2;

export const IDENTITY_TYPES = {
    Human: 0,
    Machine: 1,
    Organization: 2,
} as const;

export interface IdentityCreatedEvent {
    clone: `0x${string}`;
    id: bigint;
    identityType: IdentityType;
}

export interface IdentityInfo {
    address: `0x${string}`;
    identityId: bigint;
    owner: `0x${string}`;
    identityType: IdentityType;
    isActive: boolean;
    protocolVersion: string;
    metadataURI: string;
}

export interface IdentityTransactionResult {
    transactionHash: `0x${string}`;
    gasUsed: bigint;
    success: boolean;
}

export interface IdentityCreateResult extends IdentityTransactionResult {
    identityId: bigint;
    identityAddress: `0x${string}`;
    identityType: IdentityType;
}

export class IdentityModule {
    constructor(private readonly client: AkmenaClient) {}

    private requireAccount() {
        const account = this.client.walletClient?.account;
        if (!account) throw new WalletRequiredError();
        return account;
    }

    private async factoryAddress(): Promise<`0x${string}`> {
        return this.client.resolveModule('identity');
    }

    private async registryAddress(): Promise<`0x${string}`> {
        const factoryAddress = await this.factoryAddress();

        return this.client.publicClient.readContract({
            address: factoryAddress,
            abi: IdentityFactoryABI,
            functionName: 'registry',
        });
    }

    public async create(
        identityType: IdentityType,
        metadataURI: string,
    ): Promise<IdentityCreateResult> {
        const account = this.requireAccount();
        const factoryAddress = await this.factoryAddress();

        try {
            const { request } = await this.client.publicClient.simulateContract({
                address: factoryAddress,
                abi: IdentityFactoryABI,
                functionName: 'createIdentity',
                args: [identityType, metadataURI],
                account,
            });

            const hash = await this.client.walletClient!.writeContract(request);
            const receipt = await this.client.publicClient.waitForTransactionReceipt({ hash });

            let created: IdentityCreatedEvent | undefined;

            for (const log of receipt.logs) {
                try {
                    const decoded = decodeEventLog({
                        abi: IdentityFactoryABI,
                        data: log.data,
                        topics: log.topics,
                    });

                    if (decoded.eventName === 'IdentityCreated') {
                        const args = decoded.args as {
                            clone: `0x${string}`;
                            id: bigint;
                            identityType: number;
                        };

                        created = {
                            clone: args.clone,
                            id: args.id,
                            identityType: args.identityType as IdentityType,
                        };
                        break;
                    }
                } catch {
                    // Ignore unrelated logs.
                }
            }

            if (!created) {
                throw new Error('IdentityCreated event not found in transaction receipt.');
            }

            return {
                transactionHash: hash,
                gasUsed: receipt.gasUsed,
                success: receipt.status === 'success',
                identityId: created.id,
                identityAddress: created.clone,
                identityType: created.identityType,
            };
        } catch (error) {
            translateContractError(error);
        }
    }

    public async get(identityId: bigint): Promise<IdentityInfo> {
        const registryAddress = await this.registryAddress();

        try {
            const identityAddress = await this.client.publicClient.readContract({
                address: registryAddress,
                abi: RegistryABI,
                functionName: 'identityAddress',
                args: [identityId],
            });

            const [
                owner,
                identityType,
                isActive,
                protocolVersion,
                metadataURI,
            ] = await Promise.all([
                this.client.publicClient.readContract({
                    address: identityAddress,
                    abi: IdentityABI,
                    functionName: 'owner',
                }),
                this.client.publicClient.readContract({
                    address: identityAddress,
                    abi: IdentityABI,
                    functionName: 'identityType',
                }),
                this.client.publicClient.readContract({
                    address: identityAddress,
                    abi: IdentityABI,
                    functionName: 'isActive',
                }),
                this.client.publicClient.readContract({
                    address: identityAddress,
                    abi: IdentityABI,
                    functionName: 'protocolVersion',
                }),
                this.client.publicClient.readContract({
                    address: identityAddress,
                    abi: IdentityABI,
                    functionName: 'metadataURI',
                }),
            ]);

            return {
                address: identityAddress,
                identityId,
                owner,
                identityType: identityType as IdentityType,
                isActive,
                protocolVersion,
                metadataURI,
            };
        } catch (error) {
            translateContractError(error);
        }
    }

    public async getByAddress(
        identityAddress: `0x${string}`,
    ): Promise<bigint> {
        const registryAddress = await this.registryAddress();

        try {
            return await this.client.publicClient.readContract({
                address: registryAddress,
                abi: RegistryABI,
                functionName: 'identityId',
                args: [identityAddress],
            });
        } catch (error) {
            translateContractError(error);
        }
    }

    public async exists(identityId: bigint): Promise<boolean> {
        const registryAddress = await this.registryAddress();

        try {
            return await this.client.publicClient.readContract({
                address: registryAddress,
                abi: RegistryABI,
                functionName: 'exists',
                args: [identityId],
            });
        } catch (error) {
            translateContractError(error);
        }
    }

    public async nextId(): Promise<bigint> {
        const registryAddress = await this.registryAddress();

        try {
            return await this.client.publicClient.readContract({
                address: registryAddress,
                abi: RegistryABI,
                functionName: 'nextIdentityId',
            });
        } catch (error) {
            translateContractError(error);
        }
    }

    public async updateMetadata(
        identityId: bigint,
        metadataURI: string,
    ): Promise<IdentityTransactionResult> {
        const account = this.requireAccount();
        const identity = await this.resolveIdentityAddress(identityId);

        try {
            const { request } = await this.client.publicClient.simulateContract({
                address: identity,
                abi: IdentityABI,
                functionName: 'updateMetadata',
                args: [metadataURI],
                account,
            });

            const hash = await this.client.walletClient!.writeContract(request);
            const receipt = await this.client.publicClient.waitForTransactionReceipt({ hash });

            return {
                transactionHash: hash,
                gasUsed: receipt.gasUsed,
                success: receipt.status === 'success',
            };
        } catch (error) {
            translateContractError(error);
        }
    }

    public async transferOwnership(
        identityId: bigint,
        newOwner: `0x${string}`,
    ): Promise<IdentityTransactionResult> {
        const account = this.requireAccount();
        const identity = await this.resolveIdentityAddress(identityId);

        try {
            const { request } = await this.client.publicClient.simulateContract({
                address: identity,
                abi: IdentityABI,
                functionName: 'transferOwnership',
                args: [newOwner],
                account,
            });

            const hash = await this.client.walletClient!.writeContract(request);
            const receipt = await this.client.publicClient.waitForTransactionReceipt({ hash });

            return {
                transactionHash: hash,
                gasUsed: receipt.gasUsed,
                success: receipt.status === 'success',
            };
        } catch (error) {
            translateContractError(error);
        }
    }

    public async deactivate(
        identityId: bigint,
    ): Promise<IdentityTransactionResult> {
        const account = this.requireAccount();
        const identity = await this.resolveIdentityAddress(identityId);

        try {
            const { request } = await this.client.publicClient.simulateContract({
                address: identity,
                abi: IdentityABI,
                functionName: 'deactivate',
                account,
            });

            const hash = await this.client.walletClient!.writeContract(request);
            const receipt = await this.client.publicClient.waitForTransactionReceipt({ hash });

            return {
                transactionHash: hash,
                gasUsed: receipt.gasUsed,
                success: receipt.status === 'success',
            };
        } catch (error) {
            translateContractError(error);
        }
    }

    public async onCreated(
        callback: (event: IdentityCreatedEvent) => void,
    ): Promise<WatchContractEventReturnType> {
        const factoryAddress = await this.factoryAddress();

        return this.client.publicClient.watchContractEvent({
            address: factoryAddress,
            abi: IdentityFactoryABI,
            eventName: 'IdentityCreated',
            onLogs: logs => {
                for (const log of logs) {
                    try {
                        const decoded = decodeEventLog({
                            abi: IdentityFactoryABI,
                            data: log.data,
                            topics: log.topics,
                        });

                        if (decoded.eventName === 'IdentityCreated') {
                            const args = decoded.args as {
                                clone: `0x${string}`;
                                id: bigint;
                                identityType: number;
                            };

                            callback({
                                clone: args.clone,
                                id: args.id,
                                identityType: args.identityType as IdentityType,
                            });
                        }
                    } catch {
                        // Ignore malformed or unrelated logs.
                    }
                }
            },
        });
    }

    private async resolveIdentityAddress(identityId: bigint): Promise<`0x${string}`> {
        const registryAddress = await this.registryAddress();

        return this.client.publicClient.readContract({
            address: registryAddress,
            abi: RegistryABI,
            functionName: 'identityAddress',
            args: [identityId],
        });
    }
}
