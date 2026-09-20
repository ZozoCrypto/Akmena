import { describe, expect, it } from 'vitest';
import type {
    IdentityCreatedEvent,
    IdentityInfo,
} from '../src/modules/IdentityModule';
import type {
    HealthStatus,
} from '../src/types/protocol';

describe('Akmena public API types', () => {
    it('defines a typed IdentityCreated event', () => {
        const event: IdentityCreatedEvent = {
            clone: '0x1111111111111111111111111111111111111111',
            id: 1n,
            identityType: 1,
        };

        expect(event.clone).toMatch(/^0x[a-f0-9]{40}$/);
        expect(event.id).toBe(1n);
        expect(event.identityType).toBe(1);
    });

    it('defines a typed IdentityInfo object', () => {
        const identity: IdentityInfo = {
            address: '0x1111111111111111111111111111111111111111',
            identityId: 1n,
            owner: '0x2222222222222222222222222222222222222222',
            identityType: 1,
            isActive: true,
            protocolVersion: '2.0.0',
            metadataURI: 'ipfs://identity',
        };

        expect(identity.address).toMatch(/^0x[a-f0-9]{40}$/);
        expect(identity.identityId).toBe(1n);
        expect(identity.owner).toMatch(/^0x[a-f0-9]{40}$/);
        expect(identity.metadataURI).toBe('ipfs://identity');
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
