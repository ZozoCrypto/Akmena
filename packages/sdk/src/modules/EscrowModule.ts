import { AkmenaClient } from '../client/AkmenaClient';
import { translateContractError } from '../errors';
import { EscrowEngineABI } from '../abis/EscrowEngine';

export class EscrowModule {
    constructor(private client: AkmenaClient) {}

    public async create(escrowId: `0x${string}`, payee: `0x${string}`, amount: bigint) {
        if (!this.client.walletClient?.account) throw new Error("Wallet required.");
        const address = await this.client.resolveModule('escrow');

        try {
            const { request } = await this.client.publicClient.simulateContract({
                address, abi: EscrowEngineABI, functionName: 'createEscrow',
                args: [escrowId, payee], value: amount, account: this.client.walletClient.account
            });
            const hash = await this.client.walletClient.writeContract(request);
            return await this.client.publicClient.waitForTransactionReceipt({ hash });
        } catch (error: any) {
            translateContractError(error);
        }
    }

    public async release(escrowId: `0x${string}`) {
        if (!this.client.walletClient?.account) throw new Error("Wallet required.");
        const address = await this.client.resolveModule('escrow');

        try {
            const { request } = await this.client.publicClient.simulateContract({
                address, abi: EscrowEngineABI, functionName: 'release',
                args: [escrowId], account: this.client.walletClient.account
            });
            const hash = await this.client.walletClient.writeContract(request);
            return await this.client.publicClient.waitForTransactionReceipt({ hash });
        } catch (error: any) {
            translateContractError(error);
        }
    }
}
