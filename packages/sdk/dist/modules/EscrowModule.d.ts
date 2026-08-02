import { AkmenaClient } from '../client/AkmenaClient';
export declare class EscrowModule {
    private client;
    constructor(client: AkmenaClient);
    create(escrowId: `0x${string}`, payee: `0x${string}`, amount: bigint): Promise<import("viem").TransactionReceipt>;
    release(escrowId: `0x${string}`): Promise<import("viem").TransactionReceipt>;
}
