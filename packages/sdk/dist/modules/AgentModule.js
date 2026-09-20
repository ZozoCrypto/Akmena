"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.AgentModule = void 0;
const viem_1 = require("viem");
const errors_1 = require("../errors");
const AgentRegistry_1 = require("../abis/AgentRegistry");
class AgentModule {
    client;
    constructor(client) {
        this.client = client;
    }
    async register(agentId, metadataURI) {
        if (!this.client.walletClient?.account)
            throw new errors_1.WalletRequiredError();
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
            throw new errors_1.WalletRequiredError();
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
            address,
            abi: AgentRegistry_1.AgentRegistryABI,
            eventName: 'AgentRegistered',
            onLogs: logs => {
                for (const log of logs) {
                    try {
                        const decoded = (0, viem_1.decodeEventLog)({
                            abi: AgentRegistry_1.AgentRegistryABI,
                            data: log.data,
                            topics: log.topics,
                        });
                        if (decoded.eventName === 'AgentRegistered') {
                            const args = decoded.args;
                            callback({
                                id: args.id,
                                owner: args.owner,
                                metadataURI: args.metadataURI,
                            });
                        }
                    }
                    catch {
                        // Ignore malformed or unrelated logs.
                    }
                }
            },
        });
    }
}
exports.AgentModule = AgentModule;
//# sourceMappingURL=AgentModule.js.map