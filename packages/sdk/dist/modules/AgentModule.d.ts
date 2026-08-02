import { WatchContractEventReturnType } from 'viem';
import { AkmenaClient } from '../client/AkmenaClient';
export declare class AgentModule {
    private client;
    constructor(client: AkmenaClient);
    register(agentId: `0x${string}`, metadataURI: string): Promise<{
        transactionHash: `0x${string}`;
        gasUsed: bigint;
        success: boolean;
    }>;
    updateMetadata(agentId: `0x${string}`, metadataURI: string): Promise<import("viem").TransactionReceipt>;
    onRegistered(callback: (log: any) => void): Promise<WatchContractEventReturnType>;
}
