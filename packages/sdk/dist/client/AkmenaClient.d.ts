import { PublicClient, WalletClient, Chain } from 'viem';
import { MODULE_KEYS } from '../constants/modules';
import { HealthStatus, ModuleInfo } from '../types/protocol';
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
export declare class AkmenaClient {
    publicClient: PublicClient;
    walletClient?: WalletClient;
    coreAddress: `0x${string}`;
    chain: Chain;
    private addressCache;
    private versionVerified;
    readonly workflow: WorkflowModule;
    readonly agent: AgentModule;
    readonly escrow: EscrowModule;
    readonly payments: PaymentsModule;
    constructor(config: ClientConfig);
    withWallet(wallet: WalletClient): AkmenaClient;
    private verifyProtocolVersion;
    resolveModule(moduleName: keyof typeof MODULE_KEYS): Promise<`0x${string}`>;
    hasModule(moduleName: keyof typeof MODULE_KEYS): Promise<boolean>;
    listCachedModules(): Record<string, ModuleInfo>;
    invalidateCache(): void;
    health(): Promise<HealthStatus>;
}
