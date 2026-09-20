import { decodeEventLog, WatchContractEventReturnType } from 'viem';
import { AkmenaClient } from '../client/AkmenaClient';
import { translateContractError, WalletRequiredError } from '../errors';
import { AgentRegistryABI } from '../abis/AgentRegistry';

export interface AgentRegisteredEvent {
    id: `0x${string}`;
    owner: `0x${string}`;
    metadataURI: string;
}

export class AgentModule {
    constructor(private client: AkmenaClient) {}

    public async register(agentId: `0x${string}`, metadataURI: string) {
        if (!this.client.walletClient?.account) throw new WalletRequiredError();
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
        if (!this.client.walletClient?.account) throw new WalletRequiredError();
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

    public async onRegistered(
        callback: (event: AgentRegisteredEvent) => void,
    ): Promise<WatchContractEventReturnType> {
        const address = await this.client.resolveModule('identity');

        return this.client.publicClient.watchContractEvent({
            address,
            abi: AgentRegistryABI,
            eventName: 'AgentRegistered',
            onLogs: logs => {
                for (const log of logs) {
                    try {
                        const decoded = decodeEventLog({
                            abi: AgentRegistryABI,
                            data: log.data,
                            topics: log.topics,
                        });

                        if (decoded.eventName === 'AgentRegistered') {
                            const args = decoded.args as {
                                id: `0x${string}`;
                                owner: `0x${string}`;
                                metadataURI: string;
                            };

                            callback({
                                id: args.id,
                                owner: args.owner,
                                metadataURI: args.metadataURI,
                            });
                        }
                    } catch {
                        // Ignore malformed or unrelated logs.
                    }
                }
            },
        });
    }
}
