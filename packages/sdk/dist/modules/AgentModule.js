"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.AgentModule = void 0;
const errors_1 = require("../errors");
const AgentRegistry_1 = require("../abis/AgentRegistry");
class AgentModule {
    client;
    constructor(client) {
        this.client = client;
    }
    async register(agentId, metadataURI) {
        if (!this.client.walletClient?.account)
            throw new Error("Wallet required.");
        const address = await this.client.resolveModule('identity');
        try {
            const { request } = await this.client.publicClient.simulateContract({
                address, abi: AgentRegistry_1.AgentRegistryABI, functionName: 'register',
                args: [agentId, metadataURI], account: this.client.walletClient.account
            });
            const hash = await this.client.walletClient.writeContract(request);
            const receipt = await this.client.publicClient.waitForTransactionReceipt({ hash });
            return { transactionHash: hash, gasUsed: receipt.gasUsed, success: receipt.status === 'success' };
        }
        catch (error) {
            (0, errors_1.translateContractError)(error);
        }
    }
    async updateMetadata(agentId, metadataURI) {
        if (!this.client.walletClient?.account)
            throw new Error("Wallet required.");
        const address = await this.client.resolveModule('identity');
        try {
            const { request } = await this.client.publicClient.simulateContract({
                address, abi: AgentRegistry_1.AgentRegistryABI, functionName: 'updateMetadata',
                args: [agentId, metadataURI], account: this.client.walletClient.account
            });
            const hash = await this.client.walletClient.writeContract(request);
            return await this.client.publicClient.waitForTransactionReceipt({ hash });
        }
        catch (error) {
            (0, errors_1.translateContractError)(error);
        }
    }
    async onRegistered(callback) {
        const address = await this.client.resolveModule('identity');
        return this.client.publicClient.watchContractEvent({
            address, abi: AgentRegistry_1.AgentRegistryABI, eventName: 'AgentRegistered',
            onLogs: logs => logs.forEach(log => callback(log))
        });
    }
}
exports.AgentModule = AgentModule;
//# sourceMappingURL=AgentModule.js.map