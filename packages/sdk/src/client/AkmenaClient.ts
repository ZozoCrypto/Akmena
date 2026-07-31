import { createPublicClient, http, PublicClient, WalletClient, getContract } from 'viem';
import { base } from 'viem/chains';
import { UnsupportedProtocolVersionError, ModuleUnavailableError } from '../errors';
import { MODULE_KEYS } from '../constants/modules';
import { HealthStatus, ModuleInfo } from '../types/protocol';
import { AkmenaCoreABI } from '../abis/AkmenaCore';
import { WorkflowModule } from '../modules/WorkflowModule';

export interface ClientConfig {
    coreAddress: `0x${string}`;
    rpcUrl?: string;
    wallet?: WalletClient;
}

export class AkmenaClient {
    public publicClient: PublicClient;
    public walletClient?: WalletClient;
    public coreAddress: `0x${string}`;
    
    private addressCache: Record<string, ModuleInfo> = {};
    private versionVerified = false;

    public readonly workflow: WorkflowModule;

    constructor(config: ClientConfig) {
        this.coreAddress = config.coreAddress;
        this.walletClient = config.wallet;
        this.publicClient = createPublicClient({ chain: base, transport: http(config.rpcUrl) });
        this.workflow = new WorkflowModule(this);
    }

    public withWallet(wallet: WalletClient): AkmenaClient {
        return new AkmenaClient({ coreAddress: this.coreAddress, rpcUrl: this.publicClient.transport?.url, wallet });
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
