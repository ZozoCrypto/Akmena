"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.PaymentsModule = void 0;
const errors_1 = require("../errors");
const PaymentsEngine_1 = require("../abis/PaymentsEngine");
class PaymentsModule {
    client;
    constructor(client) {
        this.client = client;
    }
    async execute(from, to, amount) {
        const account = this.client.walletClient?.account;
        if (!account) {
            throw new errors_1.WalletRequiredError();
        }
        const address = await this.client.resolveModule('payments');
        try {
            const { request } = await this.client.publicClient.simulateContract({
                address,
                abi: PaymentsEngine_1.PaymentsEngineABI,
                functionName: 'executePayment',
                args: [from, to, amount],
                account,
            });
            const hash = await this.client.walletClient.writeContract(request);
            const receipt = await this.client.publicClient.waitForTransactionReceipt({ hash });
            return {
                transactionHash: hash,
                gasUsed: receipt.gasUsed,
                success: receipt.status === 'success',
            };
        }
        catch (error) {
            (0, errors_1.translateContractError)(error);
        }
    }
    async getTotalVolume() {
        const address = await this.client.resolveModule('payments');
        try {
            return await this.client.publicClient.readContract({
                address,
                abi: PaymentsEngine_1.PaymentsEngineABI,
                functionName: 'getTotalVolume',
            });
        }
        catch (error) {
            (0, errors_1.translateContractError)(error);
        }
    }
}
exports.PaymentsModule = PaymentsModule;
//# sourceMappingURL=PaymentsModule.js.map