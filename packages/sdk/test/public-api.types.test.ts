import { describe, expect, it } from 'vitest';
import type {
    AgentRegisteredEvent,
} from '../src/modules/AgentModule';
import type {
    HealthStatus,
} from '../src/types/protocol';

describe('Akmena public API types', () => {
    it('defines a typed AgentRegistered event', () => {
        const event: AgentRegisteredEvent = {
            id: '0x1111111111111111111111111111111111111111111111111111111111111111',
            owner: '0x1111111111111111111111111111111111111111',
            metadataURI: 'ipfs://agent',
        };

        expect(event.id).toMatch(/^0x[a-f0-9]{64}$/);
        expect(event.owner).toMatch(/^0x[a-f0-9]{40}$/);
        expect(event.metadataURI).toBe('ipfs://agent');
    });

    it('defines diagnostic health fields', () => {
        const health: HealthStatus = {
            healthy: true,
            network: 8453,
            coreAddress:
                '0x1111111111111111111111111111111111111111',
            protocolVersion: '2.0.0',
            paused: false,
            modules: {},
            readOnly: true,
            rpcReachable: true,
            coreReachable: true,
            versionSupported: true,
            failureReasons: [],
        };

        expect(health.healthy).toBe(true);
        expect(health.failureReasons).toEqual([]);
    });
});
