import { createPublicClient, http, PublicClient, WalletClient, getContract } from 'viem';
import { base } from 'viem/chains';
import { Agent } from '../agent/Agent';

// Minimal ABI for AkmenaCore router discovery
const CORE_ABI = [
    {
        type: "function",
        name: "getModule",
        inputs: [{ name: "key", type: "bytes32" }],
        outputs: [
            { name: "moduleAddress", type: "address" },
            { name: "isEnabled", type: "bool" },
            { name: "version", type: "string" }
        ],
        stateMutability: "view"
    }
] as const;

export interface ClientConfig {
    coreAddress: `0x${string}`;
    rpcUrl?: string;
}

export class AkmenaClient {
    public publicClient: PublicClient;
    public coreAddress: `0x${string}`;
    public modules: Record<string, `0x${string}`> = {};
    private walletClient?: WalletClient;

    constructor(config: ClientConfig) {
        this.coreAddress = config.coreAddress;
        this.publicClient = createPublicClient({
            chain: base,
            transport: http(config.rpcUrl)
        });
    }

    /**
     * Discovers and caches all protocol module addresses exactly once.
     */
    public async init(): Promise<void> {
        const core = getContract({ address: this.coreAddress, abi: CORE_ABI, client: this.publicClient });
        
        // Example discovery keys
        const keys = {
            identity: "0x" + Buffer.from("akmena.module.identity").toString('hex').padEnd(64, '0'),
            workflow: "0x" + Buffer.from("akmena.module.workflow").toString('hex').padEnd(64, '0')
        } as const;

        const [idData, wfData] = await Promise.all([
            core.read.getModule([keys.identity]),
            core.read.getModule([keys.workflow])
        ]);

        this.modules['identity'] = idData[0] as `0x${string}`;
        this.modules['workflow'] = wfData[0] as `0x${string}`;
    }

    /**
     * Upgrades the read-only client to a write-enabled client.
     */
    public connect(wallet: WalletClient): AkmenaClient {
        const connectedClient = new AkmenaClient({ coreAddress: this.coreAddress });
        connectedClient.modules = this.modules;
        connectedClient.walletClient = wallet;
        return connectedClient;
    }

    /**
     * Initializes an object-oriented Agent wrapper for high-level operations.
     */
    public getAgent(identityId: `0x${string}`): Agent {
        return new Agent(this, identityId, this.walletClient);
    }
}
