import { AkmenaClient } from '../client/AkmenaClient';
export declare class PaymentsModule {
    private readonly client;
    constructor(client: AkmenaClient);
    execute(from: `0x${string}`, to: `0x${string}`, amount: bigint): Promise<{
        transactionHash: `0x${string}`;
        gasUsed: bigint;
        success: boolean;
    }>;
    getTotalVolume(): Promise<bigint>;
}
