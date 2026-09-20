import { createPublicClient, http, PublicClient, WalletClient, getContract, Chain } from 'viem';
import { UnsupportedProtocolVersionError, ModuleUnavailableError } from '../errors';
import { MODULE_KEYS } from '../constants/modules';
import { HealthStatus, ModuleInfo } from '../types/protocol';
import { AkmenaCoreABI } from '../abis/AkmenaCore';

import { WorkflowModule } from '../modules/WorkflowModule';
import { IdentityModule } from '../modules/IdentityModule';
import { EscrowModule } from '../modules/EscrowModule';
import { PaymentsModule } from '../modules/PaymentsModule';
import { MarketplaceModule } from '../modules/MarketplaceModule';

export interface ClientConfig {
    coreAddress: `0x${string}`;
    chain: Chain;
    rpcUrl?: string;
    wallet?: WalletClient;
}

export class AkmenaClient {
    public publicClient: PublicClient;
    public walletClient?: WalletClient;
    public coreAddress: `0x${string}`;
    public chain: Chain;
    private readonly rpcUrl?: string;

    private addressCache: Record<string, ModuleInfo> = {};
    private versionVerified = false;

    // Business Wrappers
    public readonly workflow: WorkflowModule;
    public readonly identity: IdentityModule;
    public readonly escrow: EscrowModule;
    public readonly payments: PaymentsModule;
    public readonly marketplace: MarketplaceModule;

    constructor(config: ClientConfig) {
        this.coreAddress = config.coreAddress;
        this.chain = config.chain;
        this.walletClient = config.wallet;
        this.publicClient = createPublicClient({ chain: this.chain, transport: http(config.rpcUrl) });
        
        this.workflow = new WorkflowModule(this);
        this.identity = new IdentityModule(this);
        this.escrow = new EscrowModule(this);
        this.payments = new PaymentsModule(this);
        this.marketplace = new MarketplaceModule(this);
    }

    public withWallet(wallet: WalletClient): AkmenaClient {
        return new AkmenaClient({ coreAddress: this.coreAddress, chain: this.chain, rpcUrl: this.publicClient.transport?.url, wallet });
    }

    private async verifyProtocolVersion(): Promise<void> {
        if (this.versionVerified) return;
        const core = getContract({ address: this.coreAddress, abi: AkmenaCoreABI, client: this.publicClient });
        const version = await core.read.PROTOCOL_VERSION().catch(() => "unknown");
        if (!version.startsWith("2.")) throw new UnsupportedProtocolVersionError("2.x", version);
        this.versionVerified = true;
    }

    public async resolveModule(moduleName: keyof typeof MODULE_KEYS): Promise<`0x${string}`> {
        await this.verifyProtocolVersion();
        if (this.addressCache[moduleName]?.address) return this.addressCache[moduleName].address;

        const core = getContract({ address: this.coreAddress, abi: AkmenaCoreABI, client: this.publicClient });
        const key = MODULE_KEYS[moduleName];
        
        const [addr, isEnabled, version] = await core.read.getModule([key]);
        if (!isEnabled || addr === "0x0000000000000000000000000000000000000000") {
            throw new ModuleUnavailableError(moduleName);
        }

        this.addressCache[moduleName] = { address: addr, enabled: isEnabled, version };
        return addr;
    }

    public async hasModule(moduleName: keyof typeof MODULE_KEYS): Promise<boolean> {
        try {
            await this.resolveModule(moduleName);
            return true;
        } catch {
            return false;
        }
    }

    public listCachedModules(): Record<string, ModuleInfo> {
        return { ...this.addressCache };
    }

    public invalidateCache(): void {
        this.addressCache = {};
        this.versionVerified = false;
    }

    public async health(): Promise<HealthStatus> {
        const failureReasons: string[] = [];

        let rpcReachable = false;
        let coreReachable = false;
        let version = "unknown";
        let paused = false;
        let network = 0;

        try {
            network = await this.publicClient.getChainId();
            rpcReachable = true;
        } catch {
            failureReasons.push("RPC_UNREACHABLE");
        }

        if (rpcReachable) {
            try {
                const core = getContract({
                    address: this.coreAddress,
                    abi: AkmenaCoreABI,
                    client: this.publicClient,
                });

                version = await core.read.PROTOCOL_VERSION();
                coreReachable = true;

                try {
                    paused = await core.read.isPaused();
                } catch {
                    failureReasons.push("CORE_PAUSE_STATUS_UNAVAILABLE");
                }
            } catch {
                failureReasons.push("CORE_UNREACHABLE");
            }
        }

        const versionSupported = version.startsWith("2.");

        if (!versionSupported) {
            failureReasons.push("UNSUPPORTED_PROTOCOL_VERSION");
        }

        if (paused) {
            failureReasons.push("PROTOCOL_PAUSED");
        }

        return {
            healthy:
                rpcReachable &&
                coreReachable &&
                versionSupported &&
                !paused,
            network,
            coreAddress: this.coreAddress,
            protocolVersion: version,
            paused,
            modules: { ...this.addressCache },
            readOnly: !this.walletClient,
            rpcReachable,
            coreReachable,
            versionSupported,
            failureReasons,
        };
    }
}
