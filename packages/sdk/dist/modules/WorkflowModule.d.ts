import { AkmenaClient } from '../client/AkmenaClient';
export interface WorkflowCompletionResult {
    workflowId: `0x${string}`;
    transactionHash: `0x${string}`;
    gasUsed: bigint;
    events: {
        workflowAdvanced?: boolean;
    };
}
export declare class WorkflowModule {
    private client;
    constructor(client: AkmenaClient);
    complete(workflowId: `0x${string}`, data: {
        settlement: `0x${string}`;
        memory: `0x${string}`;
        reputation: `0x${string}`;
    }): Promise<WorkflowCompletionResult>;
}
