import { AkmenaClient } from '../client/AkmenaClient';
import { translateContractError } from '../errors';
import { PaymentsEngineABI } from '../abis/PaymentsEngine';

export class PaymentsModule {
    constructor(private client: AkmenaClient) {}

    public async execute(paymentId: `0x${string}`, to: `0x${string}`, amount: bigint) {
        if (!this.client.walletClient?.account) throw new Error("Wallet required.");
        // Note: For demonstration. Core module keys might need a 'payments' key added if it's separate from Settlement.
        const address = await this.client.resolveModule('settlement'); 

        try {
            const { request } = await this.client.publicClient.simulateContract({
                address, abi: PaymentsEngineABI, functionName: 'executePayment',
                args: [paymentId, to, amount], account: this.client.walletClient.account
            });
            const hash = await this.client.walletClient.writeContract(request);
            return await this.client.publicClient.waitForTransactionReceipt({ hash });
        } catch (error: any) {
            translateContractError(error);
        }
    }
}
