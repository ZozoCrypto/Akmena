import { AkmenaClient } from '../client/AkmenaClient';
import { translateContractError, WalletRequiredError } from '../errors';
import { PaymentsEngineABI } from '../abis/PaymentsEngine';

export class PaymentsModule {
    constructor(private readonly client: AkmenaClient) {}

    public async execute(
        from: `0x${string}`,
        to: `0x${string}`,
        amount: bigint,
    ) {
        const account = this.client.walletClient?.account;
        if (!account) {
            throw new WalletRequiredError();
        }

        const address = await this.client.resolveModule('payments');

        try {
            const { request } = await this.client.publicClient.simulateContract({
                address,
                abi: PaymentsEngineABI,
                functionName: 'executePayment',
                args: [from, to, amount],
                account,
            });

            const hash = await this.client.walletClient!.writeContract(request);
            const receipt = await this.client.publicClient.waitForTransactionReceipt({ hash });

            return {
                transactionHash: hash,
                gasUsed: receipt.gasUsed,
                success: receipt.status === 'success',
            };
        } catch (error: unknown) {
            translateContractError(error);
        }
    }

    public async getTotalVolume(): Promise<bigint> {
        const address = await this.client.resolveModule('payments');

        try {
            return await this.client.publicClient.readContract({
                address,
                abi: PaymentsEngineABI,
                functionName: 'getTotalVolume',
            });
        } catch (error: unknown) {
            translateContractError(error);
        }
    }
}
