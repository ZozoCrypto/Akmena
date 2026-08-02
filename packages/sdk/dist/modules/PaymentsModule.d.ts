import { AkmenaClient } from '../client/AkmenaClient';
export declare class PaymentsModule {
    private client;
    constructor(client: AkmenaClient);
    execute(paymentId: `0x${string}`, to: `0x${string}`, amount: bigint): Promise<import("viem").TransactionReceipt>;
}
