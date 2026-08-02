"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.Agent = void 0;
class Agent {
    id;
    client;
    constructor(id, client) {
        this.id = id;
        this.client = client;
    }
    async getWorkflowModuleAddress() {
        return await this.client.resolveModule('workflow');
    }
}
exports.Agent = Agent;
//# sourceMappingURL=Agent.js.map