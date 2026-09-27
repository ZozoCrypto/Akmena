import { decodeEventLog } from 'viem';
import { AkmenaClient } from '../client/AkmenaClient';
import { translateContractError, WalletRequiredError } from '../errors';
import { WorkflowEngineABI } from '../abis/WorkflowEngine';

export interface WorkflowInitializationResult {
    workflowId: `0x${string}`;
    transactionHash: `0x${string}`;
    gasUsed: bigint;
}

export interface WorkflowCompletionResult {
    workflowId: `0x${string}`;
    transactionHash: `0x${string}`;
    gasUsed: bigint;
    events: {
        workflowAdvanced?: boolean;
    };
}

export class WorkflowModule {
    constructor(private client: AkmenaClient) {}

    public async initialize(
        identityId: bigint,
        agreementId: `0x${string}`,
        escrowId: `0x${string}`,
    ): Promise<WorkflowInitializationResult> {
        if (!this.client.walletClient || !this.client.walletClient.account) {
            throw new WalletRequiredError();
        }

        const address = await this.client.resolveModule('workflow');

        try {
            const { request } = await this.client.publicClient.simulateContract({
                address,
                abi: WorkflowEngineABI,
                functionName: 'initializeWorkflow',
                args: [identityId, agreementId, escrowId],
                account: this.client.walletClient.account,
            });

            const txHash = await this.client.walletClient.writeContract(request);
            const receipt = await this.client.publicClient.waitForTransactionReceipt({
                hash: txHash,
            });

            for (const log of receipt.logs) {
                try {
                    const decoded = decodeEventLog({
                        abi: WorkflowEngineABI,
                        data: log.data,
                        topics: log.topics,
                    });

                    if (decoded.eventName === 'WorkflowInitialized') {
                        return {
                            workflowId: decoded.args.workflowId,
                            transactionHash: receipt.transactionHash,
                            gasUsed: receipt.gasUsed,
                        };
                    }
                } catch {
                    // Ignore unrelated logs.
                }
            }

            throw new Error('WorkflowInitialized event not found');
        } catch (error: unknown) {
            translateContractError(error);
        }
    }

    public async complete(workflowId: `0x${string}`, data: { settlement: `0x${string}`, memory: `0x${string}`, reputation: `0x${string}` }): Promise<WorkflowCompletionResult> {
        if (!this.client.walletClient || !this.client.walletClient.account) {
            throw new WalletRequiredError();
        }

        const address = await this.client.resolveModule('workflow');

        try {
            const { request } = await this.client.publicClient.simulateContract({
                address, 
                abi: WorkflowEngineABI, 
                functionName: 'advanceToCompletion',
                args: [workflowId, data.settlement, data.memory, data.reputation],
                account: this.client.walletClient.account
            });

            const txHash = await this.client.walletClient.writeContract(request);
            const receipt = await this.client.publicClient.waitForTransactionReceipt({ hash: txHash });

            const parsedEvents: WorkflowCompletionResult['events'] = {};
            for (const log of receipt.logs) {
                try {
                    const decoded = decodeEventLog({ abi: WorkflowEngineABI, data: log.data, topics: log.topics });
                    if (decoded.eventName === 'WorkflowAdvanced') parsedEvents.workflowAdvanced = true;
                } catch { /* Ignore non-matching logs */ }
            }

            return {
                workflowId,
                transactionHash: receipt.transactionHash,
                gasUsed: receipt.gasUsed,
                events: parsedEvents
            };
        } catch (error: any) {
            translateContractError(error);
        }
    }
}
