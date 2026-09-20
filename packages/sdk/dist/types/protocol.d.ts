export interface ModuleInfo {
    address: `0x${string}`;
    enabled: boolean;
    version: string;
}
export interface HealthStatus {
    healthy: boolean;
    network: number;
    coreAddress: `0x${string}`;
    protocolVersion: string;
    paused: boolean;
    modules: Record<string, ModuleInfo>;
    readOnly: boolean;
    /** Whether the configured RPC endpoint responded successfully. */
    rpcReachable: boolean;
    /** Whether AkmenaCore responded successfully. */
    coreReachable: boolean;
    /** Whether the returned protocol version satisfies the SDK 2.x requirement. */
    versionSupported: boolean;
    /** Stable diagnostic codes explaining an unhealthy result. */
    failureReasons: string[];
}
