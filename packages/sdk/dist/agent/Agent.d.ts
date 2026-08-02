import { AkmenaClient } from '../client/AkmenaClient';
export declare class Agent {
    readonly id: `0x${string}`;
    private client;
    constructor(id: `0x${string}`, client: AkmenaClient);
    getWorkflowModuleAddress(): Promise<`0x${string}`>;
}
