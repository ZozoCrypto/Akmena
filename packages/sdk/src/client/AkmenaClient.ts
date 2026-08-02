import { createPublicClient, http, PublicClient, WalletClient, getContract, Chain } from 'viem';
import { UnsupportedProtocolVersionError, ModuleUnavailableError } from '../errors';
import { MODULE_KEYS } from '../constants/modules';
import { HealthStatus, ModuleInfo } from '../types/protocol';
import { AkmenaCoreABI } from '../abis/AkmenaCore';

import { WorkflowModule } from '../modules/WorkflowModule';
import { AgentModule } from '../modules/AgentModule';
import { EscrowModule } from '../modules/EscrowModule';
import { PaymentsModule } from '../modules/PaymentsModule';

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
    
    private addressCache: Record<string, ModuleInfo> = {};
    private versionVerified = false;

    // Business Wrappers
    public readonly workflow: WorkflowModule;
    public readonly agent: AgentModule;
    public readonly escrow: EscrowModule;
    public readonly payments: PaymentsModule;

    constructor(config: ClientConfig) {
        this.coreAddress = config.coreAddress;
        this.chain = config.chain;
        this.walletClient = config.wallet;
        this.publicClient = createPublicClient({ chain: this.chain, transport: http(config.rpcUrl) });
        
        this.workflow = new WorkflowModule(this);
        this.agent = new AgentModule(this);
        this.escrow = new EscrowModule(this);
        this.payments = new PaymentsModule(this);
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
        const core = getContract({ address: this.coreAddress, abi: AkmenaCoreABI, client: this.publicClient });
        const [version, paused, chainId] = await Promise.all([
            core.read.PROTOCOL_VERSION().catch(() => "unknown"),
            core.read.isPaused().catch(() => false),
            this.publicClient.getChainId()
        ]);
        
        return {
            healthy: !paused && version.startsWith("2."),
            network: chainId,
            coreAddress: this.coreAddress,
            protocolVersion: version,
            paused: paused,
            modules: this.addressCache,
            readOnly: !this.walletClient
        };
    }
}
