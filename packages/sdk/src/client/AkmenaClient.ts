import { createPublicClient, http, PublicClient, WalletClient, getContract, keccak256, toHex } from 'viem';
import { base } from 'viem/chains';
import { UnsupportedProtocolVersionError, ModuleUnavailableError } from '../errors';
import { WorkflowModule } from '../modules/WorkflowModule';

const CORE_ABI = [
    { type: "function", name: "PROTOCOL_VERSION", inputs: [], outputs: [{ type: "string" }], stateMutability: "view" },
    { type: "function", name: "getModule", inputs: [{ name: "key", type: "bytes32" }], outputs: [{ type: "address" }, { type: "bool" }, { type: "string" }], stateMutability: "view" },
    { type: "function", name: "isPaused", inputs: [], outputs: [{ type: "bool" }], stateMutability: "view" }
] as const;

export interface ClientConfig {
    coreAddress: `0x${string}`;
    rpcUrl?: string;
    wallet?: WalletClient;
}

export class AkmenaClient {
    public publicClient: PublicClient;
    public walletClient?: WalletClient;
    public coreAddress: `0x${string}`;
    
    private addressCache: Record<string, `0x${string}`> = {};
    private versionVerified = false;

    // Dedicated Module Wrappers
    public readonly workflow: WorkflowModule;

    constructor(config: ClientConfig) {
        this.coreAddress = config.coreAddress;
        this.walletClient = config.wallet;
        this.publicClient = createPublicClient({ chain: base, transport: http(config.rpcUrl) });
        
        this.workflow = new WorkflowModule(this);
    }

    public withWallet(wallet: WalletClient): AkmenaClient {
        return new AkmenaClient({ coreAddress: this.coreAddress, rpcUrl: this.publicClient.transport.url, wallet });
    }

    private async verifyProtocolVersion(): Promise<void> {
        if (this.versionVerified) return;
        const core = getContract({ address: this.coreAddress, abi: CORE_ABI, client: this.publicClient });
        const version = await core.read.PROTOCOL_VERSION().catch(() => "unknown");
        if (!version.startsWith("2.")) throw new UnsupportedProtocolVersionError("2.x", version);
        this.versionVerified = true;
    }

    public async resolveModule(moduleName: string): Promise<`0x${string}`> {
        await this.verifyProtocolVersion();
        if (this.addressCache[moduleName]) return this.addressCache[moduleName];

        const core = getContract({ address: this.coreAddress, abi: CORE_ABI, client: this.publicClient });
        // Universal encoding (no Node Buffer)
        const key = keccak256(toHex(`akmena.module.${moduleName}`));
        
        const [addr, isEnabled] = await core.read.getModule([key]);
        if (!isEnabled || addr === "0x0000000000000000000000000000000000000000") {
            throw new ModuleUnavailableError(moduleName);
        }

        this.addressCache[moduleName] = addr;
        return addr;
    }

    public async health() {
        const core = getContract({ address: this.coreAddress, abi: CORE_ABI, client: this.publicClient });
        const [version, paused] = await Promise.all([
            core.read.PROTOCOL_VERSION().catch(() => "unknown"),
            core.read.isPaused().catch(() => false)
        ]);
        
        return {
            network: await this.publicClient.getChainId(),
            protocolVersion: version,
            isPaused: paused,
            cachedModules: Object.keys(this.addressCache),
            readOnly: !this.walletClient
        };
    }
}
