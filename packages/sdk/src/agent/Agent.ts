import { WalletClient, encodeFunctionData, decodeEventLog } from 'viem';
import { AkmenaClient } from '../client/AkmenaClient';
import { translateContractError } from '../errors';

const WORKFLOW_ABI = [
    {
        type: "function",
        name: "advanceToCompletion",
        inputs: [
            { name: "workflowId", type: "bytes32" },
            { name: "settlementData", type: "bytes" },
            { name: "memoryData", type: "bytes" },
            { name: "reputationData", type: "bytes" }
        ],
        outputs: [],
        stateMutability: "nonpayable"
    }
] as const;

export class Agent {
    constructor(
        private client: AkmenaClient,
        public identityId: `0x${string}`,
        private wallet?: WalletClient
    ) {}

    /**
     * High-Level API: Advances a workflow and automatically decodes resulting events.
     */
    public async completeJob(workflowId: `0x${string}`, resultData: {
        settlement: `0x${string}`,
        memory: `0x${string}`,
        reputation: `0x${string}`
    }) {
        if (!this.wallet || !this.wallet.account) {
            throw new Error("WalletClient required to execute transactions.");
        }

        const workflowEngine = this.client.modules['workflow'];
        if (!workflowEngine) throw new Error("Workflow Engine address not discovered. Call init() first.");

        try {
            // 1. Low-level transaction submission
            const { request } = await this.client.publicClient.simulateContract({
                address: workflowEngine,
                abi: WORKFLOW_ABI,
                functionName: 'advanceToCompletion',
                args: [workflowId, resultData.settlement, resultData.memory, resultData.reputation],
                account: this.wallet.account
            });

            const txHash = await this.wallet.writeContract(request);

            // 2. Lifecycle Management: Wait for receipt
            const receipt = await this.client.publicClient.waitForTransactionReceipt({ hash: txHash });

            // 3. Event Parsing (Simplified for illustration)
            const events = receipt.logs.map(log => {
                try {
                    // In a full implementation, we pass the ABI of the emitted events
                    return log;
                } catch {
                    return null;
                }
            });

            // 4. Return managed object
            return {
                success: receipt.status === 'success',
                workflowId,
                transactionHash: receipt.transactionHash,
                gasUsed: receipt.gasUsed,
                events
            };

        } catch (error: any) {
            translateContractError(error);
        }
    }
}
