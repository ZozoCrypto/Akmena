import { WatchContractEventReturnType } from 'viem';
import { AkmenaClient } from '../client/AkmenaClient';
import { translateContractError } from '../errors';
import { AgentRegistryABI } from '../abis/AgentRegistry';

export class AgentModule {
    constructor(private client: AkmenaClient) {}

    public async register(agentId: `0x${string}`, metadataURI: string) {
        if (!this.client.walletClient?.account) throw new Error("Wallet required.");
        const address = await this.client.resolveModule('identity');

        try {
            const { request } = await this.client.publicClient.simulateContract({
                address, abi: AgentRegistryABI, functionName: 'register',
                args: [agentId, metadataURI], account: this.client.walletClient.account
            });
            const hash = await this.client.walletClient.writeContract(request);
            const receipt = await this.client.publicClient.waitForTransactionReceipt({ hash });
            return { transactionHash: hash, gasUsed: receipt.gasUsed, success: receipt.status === 'success' };
        } catch (error: any) {
            translateContractError(error);
        }
    }

    public async updateMetadata(agentId: `0x${string}`, metadataURI: string) {
        if (!this.client.walletClient?.account) throw new Error("Wallet required.");
        const address = await this.client.resolveModule('identity');

        try {
            const { request } = await this.client.publicClient.simulateContract({
                address, abi: AgentRegistryABI, functionName: 'updateMetadata',
                args: [agentId, metadataURI], account: this.client.walletClient.account
            });
            const hash = await this.client.walletClient.writeContract(request);
            return await this.client.publicClient.waitForTransactionReceipt({ hash });
        } catch (error: any) {
            translateContractError(error);
        }
    }

    public async onRegistered(callback: (log: any) => void): Promise<WatchContractEventReturnType> {
        const address = await this.client.resolveModule('identity');
        return this.client.publicClient.watchContractEvent({
            address, abi: AgentRegistryABI, eventName: 'AgentRegistered',
            onLogs: logs => logs.forEach(log => callback(log))
        });
    }
}
