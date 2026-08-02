"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.EscrowModule = void 0;
const errors_1 = require("../errors");
const EscrowEngine_1 = require("../abis/EscrowEngine");
class EscrowModule {
    client;
    constructor(client) {
        this.client = client;
    }
    async create(escrowId, payee, amount) {
        if (!this.client.walletClient?.account)
            throw new Error("Wallet required.");
        const address = await this.client.resolveModule('escrow');
        try {
            const { request } = await this.client.publicClient.simulateContract({
                address, abi: EscrowEngine_1.EscrowEngineABI, functionName: 'createEscrow',
                args: [escrowId, payee], value: amount, account: this.client.walletClient.account
            });
            const hash = await this.client.walletClient.writeContract(request);
            return await this.client.publicClient.waitForTransactionReceipt({ hash });
        }
        catch (error) {
            (0, errors_1.translateContractError)(error);
        }
    }
    async release(escrowId) {
        if (!this.client.walletClient?.account)
            throw new Error("Wallet required.");
        const address = await this.client.resolveModule('escrow');
        try {
            const { request } = await this.client.publicClient.simulateContract({
                address, abi: EscrowEngine_1.EscrowEngineABI, functionName: 'release',
                args: [escrowId], account: this.client.walletClient.account
            });
            const hash = await this.client.walletClient.writeContract(request);
            return await this.client.publicClient.waitForTransactionReceipt({ hash });
        }
        catch (error) {
            (0, errors_1.translateContractError)(error);
        }
    }
}
exports.EscrowModule = EscrowModule;
//# sourceMappingURL=EscrowModule.js.map