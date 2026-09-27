"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.EscrowModule = void 0;
const viem_1 = require("viem");
const errors_1 = require("../errors");
const EscrowEngine_1 = require("../abis/EscrowEngine");
class EscrowModule {
    client;
    constructor(client) {
        this.client = client;
    }
    requireAccount() {
        const account = this.client.walletClient?.account;
        if (!account) {
            throw new errors_1.WalletRequiredError();
        }
        return account;
    }
    async create(buyer, seller, amount, referenceId = `0x${'00'.repeat(32)}`) {
        const account = this.requireAccount();
        const address = await this.client.resolveModule('escrow');
        try {
            const { request } = await this.client.publicClient.simulateContract({
                address,
                abi: EscrowEngine_1.EscrowEngineABI,
                functionName: 'createEscrow',
                args: [buyer, seller, amount, referenceId],
                account,
            });
            const hash = await this.client.walletClient.writeContract(request);
            const receipt = await this.client.publicClient.waitForTransactionReceipt({ hash });
            let escrowId;
            for (const log of receipt.logs) {
                try {
                    const decoded = (0, viem_1.decodeEventLog)({
                        abi: EscrowEngine_1.EscrowEngineABI,
                        data: log.data,
                        topics: log.topics,
                    });
                    if (decoded.eventName === 'EscrowCreated') {
                        escrowId = decoded.args.escrowId;
                        break;
                    }
                }
                catch {
                    // Ignore unrelated logs.
                }
            }
            return {
                transactionHash: hash,
                gasUsed: receipt.gasUsed,
                escrowId,
            };
        }
        catch (error) {
            (0, errors_1.translateContractError)(error);
        }
    }
    async createWithAsset(asset, buyer, seller, amount, referenceId = `0x${'00'.repeat(32)}`) {
        const account = this.requireAccount();
        const address = await this.client.resolveModule('escrow');
        try {
            const { request } = await this.client.publicClient.simulateContract({
                address,
                abi: EscrowEngine_1.EscrowEngineABI,
                functionName: 'createEscrow',
                args: [buyer, seller, asset, amount, referenceId],
                account,
            });
            const hash = await this.client.walletClient.writeContract(request);
            const receipt = await this.client.publicClient.waitForTransactionReceipt({ hash });
            let escrowId;
            for (const log of receipt.logs) {
                try {
                    const decoded = (0, viem_1.decodeEventLog)({
                        abi: EscrowEngine_1.EscrowEngineABI,
                        data: log.data,
                        topics: log.topics,
                    });
                    if (decoded.eventName === 'EscrowCreated') {
                        escrowId = decoded.args.escrowId;
                        break;
                    }
                }
                catch {
                    // Ignore unrelated logs.
                }
            }
            return {
                transactionHash: hash,
                gasUsed: receipt.gasUsed,
                escrowId,
            };
        }
        catch (error) {
            (0, errors_1.translateContractError)(error);
        }
    }
    async release(escrowId) {
        const account = this.requireAccount();
        const address = await this.client.resolveModule('escrow');
        try {
            const { request } = await this.client.publicClient.simulateContract({
                address,
                abi: EscrowEngine_1.EscrowEngineABI,
                functionName: 'releaseEscrow',
                args: [escrowId],
                account,
            });
            const hash = await this.client.walletClient.writeContract(request);
            const receipt = await this.client.publicClient.waitForTransactionReceipt({ hash });
            return {
                transactionHash: hash,
                gasUsed: receipt.gasUsed,
            };
        }
        catch (error) {
            (0, errors_1.translateContractError)(error);
        }
    }
    async refund(escrowId) {
        const account = this.requireAccount();
        const address = await this.client.resolveModule('escrow');
        try {
            const { request } = await this.client.publicClient.simulateContract({
                address,
                abi: EscrowEngine_1.EscrowEngineABI,
                functionName: 'refundEscrow',
                args: [escrowId],
                account,
            });
            const hash = await this.client.walletClient.writeContract(request);
            const receipt = await this.client.publicClient.waitForTransactionReceipt({ hash });
            return {
                transactionHash: hash,
                gasUsed: receipt.gasUsed,
            };
        }
        catch (error) {
            (0, errors_1.translateContractError)(error);
        }
    }
    async get(escrowId) {
        const address = await this.client.resolveModule('escrow');
        try {
            return await this.client.publicClient.readContract({
                address,
                abi: EscrowEngine_1.EscrowEngineABI,
                functionName: 'getEscrow',
                args: [escrowId],
            });
        }
        catch (error) {
            (0, errors_1.translateContractError)(error);
        }
    }
}
exports.EscrowModule = EscrowModule;
//# sourceMappingURL=EscrowModule.js.map