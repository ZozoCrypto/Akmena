"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.WorkflowModule = void 0;
const viem_1 = require("viem");
const errors_1 = require("../errors");
const WorkflowEngine_1 = require("../abis/WorkflowEngine");
class WorkflowModule {
    client;
    constructor(client) {
        this.client = client;
    }
    async complete(workflowId, data) {
        if (!this.client.walletClient || !this.client.walletClient.account) {
            throw new Error("Write operations require a connected wallet.");
        }
        const address = await this.client.resolveModule('workflow');
        try {
            const { request } = await this.client.publicClient.simulateContract({
                address,
                abi: WorkflowEngine_1.WorkflowEngineABI,
                functionName: 'advanceToCompletion',
                args: [workflowId, data.settlement, data.memory, data.reputation],
                account: this.client.walletClient.account
            });
            const txHash = await this.client.walletClient.writeContract(request);
            const receipt = await this.client.publicClient.waitForTransactionReceipt({ hash: txHash });
            const parsedEvents = {};
            for (const log of receipt.logs) {
                try {
                    const decoded = (0, viem_1.decodeEventLog)({ abi: WorkflowEngine_1.WorkflowEngineABI, data: log.data, topics: log.topics });
                    if (decoded.eventName === 'WorkflowAdvanced')
                        parsedEvents.workflowAdvanced = true;
                }
                catch { /* Ignore non-matching logs */ }
            }
            return {
                workflowId,
                transactionHash: receipt.transactionHash,
                gasUsed: receipt.gasUsed,
                events: parsedEvents
            };
        }
        catch (error) {
            (0, errors_1.translateContractError)(error);
        }
    }
}
exports.WorkflowModule = WorkflowModule;
//# sourceMappingURL=WorkflowModule.js.map