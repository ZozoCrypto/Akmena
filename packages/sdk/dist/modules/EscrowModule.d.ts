import { AkmenaClient } from '../client/AkmenaClient';
export interface EscrowTransactionResult {
    transactionHash: `0x${string}`;
    gasUsed: bigint;
    escrowId?: bigint;
}
export declare class EscrowModule {
    private readonly client;
    constructor(client: AkmenaClient);
    private requireAccount;
    create(buyer: `0x${string}`, seller: `0x${string}`, amount: bigint, referenceId?: `0x${string}`): Promise<EscrowTransactionResult>;
    createWithAsset(asset: `0x${string}`, buyer: `0x${string}`, seller: `0x${string}`, amount: bigint, referenceId?: `0x${string}`): Promise<EscrowTransactionResult>;
    release(escrowId: bigint): Promise<EscrowTransactionResult>;
    refund(escrowId: bigint): Promise<EscrowTransactionResult>;
    get(escrowId: bigint): Promise<{
        buyer: `0x${string}`;
        seller: `0x${string}`;
        amount: bigint;
        asset: `0x${string}`;
        status: number;
        referenceId: `0x${string}`;
    }>;
}
