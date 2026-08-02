import { AkmenaClient } from '../client/AkmenaClient';

export class Agent {
    constructor(
        public readonly id: `0x${string}`,
        private client: AkmenaClient
    ) {}

    public async getWorkflowModuleAddress(): Promise<`0x${string}`> {
        return await this.client.resolveModule('workflow');
    }
}
