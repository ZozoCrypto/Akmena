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
}
