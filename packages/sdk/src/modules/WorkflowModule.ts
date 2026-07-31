import { encodeFunctionData, decodeEventLog } from 'viem';
import { AkmenaClient } from '../client/AkmenaClient';
import { translateContractError } from '../errors';

// Mocking ABI import - in reality, imported from generated Foundry artifacts
const WORKFLOW_ABI = [
    {
        type: "function", name: "advanceToCompletion",
        inputs: [{ name: "workflowId", type: "bytes32" }, { name: "settlementData", type: "bytes" }, { name: "memoryData", type: "bytes" }, { name: "reputationData", type: "bytes" }],
        outputs: [], stateMutability: "nonpayable"
    },
    { type: "event", name: "WorkflowAdvanced", inputs: [{ indexed: true, name: "workflowId", type: "bytes32" }, { indexed: false, name: "step", type: "uint8" }] }
] as const;

export interface WorkflowCompletionResult {
    workflowId: `0x${string}`;
    transactionHash: `0x${string}`;
    gasUsed: bigint;
    events: {
        workflowAdvanced?: boolean;
        settlementRecorded?: boolean;
    };
}

export class WorkflowModule {
    constructor(private client: AkmenaClient) {}

    public async complete(workflowId: `0x${string}`, data: { settlement: `0x${string}`, memory: `0x${string}`, reputation: `0x${string}` }): Promise<WorkflowCompletionResult> {
        if (!this.client.walletClient || !this.client.walletClient.account) {
            throw new Error("Write operations require a connected wallet.");
        }

        const address = await this.client.resolveModule('workflow');

        try {
            const { request } = await this.client.publicClient.simulateContract({
                address, abi: WORKFLOW_ABI, functionName: 'advanceToCompletion',
                args: [workflowId, data.settlement, data.memory, data.reputation],
                account: this.client.walletClient.account
            });

            const txHash = await this.client.walletClient.writeContract(request);
            const receipt = await this.client.publicClient.waitForTransactionReceipt({ hash: txHash });

            // Typed Event Parsing
            const parsedEvents: WorkflowCompletionResult['events'] = {};
            for (const log of receipt.logs) {
                try {
                    const decoded = decodeEventLog({ abi: WORKFLOW_ABI, data: log.data, topics: log.topics });
                    if (decoded.eventName === 'WorkflowAdvanced') parsedEvents.workflowAdvanced = true;
                } catch { /* Ignore logs from other contracts */ }
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
