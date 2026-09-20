import { decodeEventLog } from 'viem';
import { AkmenaClient } from '../client/AkmenaClient';
import { translateContractError, WalletRequiredError } from '../errors';
import { MarketplaceEngineABI } from '../abis/MarketplaceEngine';

export interface MarketplaceTransactionResult {
    transactionHash: `0x${string}`;
    gasUsed: bigint;
    taskId?: bigint;
    success?: boolean;
}

export class MarketplaceModule {
    constructor(private readonly client: AkmenaClient) {}

    private requireAccount() {
        const account = this.client.walletClient?.account;
        if (!account) {
            throw new WalletRequiredError();
        }
        return account;
    }

    public async create(
        reward: bigint,
    ): Promise<MarketplaceTransactionResult> {
        const account = this.requireAccount();
        const address = await this.client.resolveModule('marketplace');

        try {
            const { request } =
                await this.client.publicClient.simulateContract({
                    address,
                    abi: MarketplaceEngineABI,
                    functionName: 'createTask',
                    args: [reward],
                    account,
                });

            const hash = await this.client.walletClient!.writeContract(request);
            const receipt =
                await this.client.publicClient.waitForTransactionReceipt({
                    hash,
                });

            let taskId: bigint | undefined;

            for (const log of receipt.logs) {
                try {
                    const decoded = decodeEventLog({
                        abi: MarketplaceEngineABI,
                        data: log.data,
                        topics: log.topics,
                    });

                    if (decoded.eventName === 'TaskCreated') {
                        taskId = decoded.args.taskId;
                        break;
                    }
                } catch {
                    // Ignore unrelated logs.
                }
            }

            return {
                transactionHash: hash,
                gasUsed: receipt.gasUsed,
                taskId,
                success: receipt.status === 'success',
            };
        } catch (error: unknown) {
            translateContractError(error);
        }
    }

    public async assign(
        taskId: bigint,
        assignee: `0x${string}`,
    ): Promise<MarketplaceTransactionResult> {
        const account = this.requireAccount();
        const address = await this.client.resolveModule('marketplace');

        try {
            const { request } =
                await this.client.publicClient.simulateContract({
                    address,
                    abi: MarketplaceEngineABI,
                    functionName: 'assignTask',
                    args: [taskId, assignee],
                    account,
                });

            const hash = await this.client.walletClient!.writeContract(request);
            const receipt =
                await this.client.publicClient.waitForTransactionReceipt({
                    hash,
                });

            return {
                transactionHash: hash,
                gasUsed: receipt.gasUsed,
                taskId,
                success: receipt.status === 'success',
            };
        } catch (error: unknown) {
            translateContractError(error);
        }
    }

    public async complete(
        taskId: bigint,
    ): Promise<MarketplaceTransactionResult> {
        const account = this.requireAccount();
        const address = await this.client.resolveModule('marketplace');

        try {
            const { request } =
                await this.client.publicClient.simulateContract({
                    address,
                    abi: MarketplaceEngineABI,
                    functionName: 'completeTask',
                    args: [taskId, account.address],
                    account,
                });

            const hash = await this.client.walletClient!.writeContract(request);
            const receipt =
                await this.client.publicClient.waitForTransactionReceipt({
                    hash,
                });

            return {
                transactionHash: hash,
                gasUsed: receipt.gasUsed,
                taskId,
                success: receipt.status === 'success',
            };
        } catch (error: unknown) {
            translateContractError(error);
        }
    }

    public async get(taskId: bigint) {
        const address = await this.client.resolveModule('marketplace');

        try {
            return await this.client.publicClient.readContract({
                address,
                abi: MarketplaceEngineABI,
                functionName: 'getTask',
                args: [taskId],
            });
        } catch (error: unknown) {
            translateContractError(error);
        }
    }
}
