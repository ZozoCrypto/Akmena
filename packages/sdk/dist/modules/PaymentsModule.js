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
    async execute(paymentId, to, amount) {
        if (!this.client.walletClient?.account)
            throw new Error("Wallet required.");
        // Note: For demonstration. Core module keys might need a 'payments' key added if it's separate from Settlement.
        const address = await this.client.resolveModule('settlement');
        try {
            const { request } = await this.client.publicClient.simulateContract({
                address, abi: PaymentsEngine_1.PaymentsEngineABI, functionName: 'executePayment',
                args: [paymentId, to, amount], account: this.client.walletClient.account
            });
            const hash = await this.client.walletClient.writeContract(request);
            return await this.client.publicClient.waitForTransactionReceipt({ hash });
        }
        catch (error) {
            (0, errors_1.translateContractError)(error);
        }
    }
}
exports.PaymentsModule = PaymentsModule;
//# sourceMappingURL=PaymentsModule.js.map