"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.AkmenaClient = void 0;
const viem_1 = require("viem");
const errors_1 = require("../errors");
const modules_1 = require("../constants/modules");
const AkmenaCore_1 = require("../abis/AkmenaCore");
const WorkflowModule_1 = require("../modules/WorkflowModule");
const AgentModule_1 = require("../modules/AgentModule");
const EscrowModule_1 = require("../modules/EscrowModule");
const PaymentsModule_1 = require("../modules/PaymentsModule");
class AkmenaClient {
    publicClient;
    walletClient;
    coreAddress;
    chain;
    addressCache = {};
    versionVerified = false;
    // Business Wrappers
    workflow;
    agent;
    escrow;
    payments;
    constructor(config) {
        this.coreAddress = config.coreAddress;
        this.chain = config.chain;
        this.walletClient = config.wallet;
        this.publicClient = (0, viem_1.createPublicClient)({ chain: this.chain, transport: (0, viem_1.http)(config.rpcUrl) });
        this.workflow = new WorkflowModule_1.WorkflowModule(this);
        this.agent = new AgentModule_1.AgentModule(this);
        this.escrow = new EscrowModule_1.EscrowModule(this);
        this.payments = new PaymentsModule_1.PaymentsModule(this);
    }
    withWallet(wallet) {
        return new AkmenaClient({ coreAddress: this.coreAddress, chain: this.chain, rpcUrl: this.publicClient.transport?.url, wallet });
    }
    async verifyProtocolVersion() {
        if (this.versionVerified)
            return;
        const core = (0, viem_1.getContract)({ address: this.coreAddress, abi: AkmenaCore_1.AkmenaCoreABI, client: this.publicClient });
        const version = await core.read.PROTOCOL_VERSION().catch(() => "unknown");
        if (!version.startsWith("2."))
            throw new errors_1.UnsupportedProtocolVersionError("2.x", version);
        this.versionVerified = true;
    }
    async resolveModule(moduleName) {
        await this.verifyProtocolVersion();
        if (this.addressCache[moduleName]?.address)
            return this.addressCache[moduleName].address;
        const core = (0, viem_1.getContract)({ address: this.coreAddress, abi: AkmenaCore_1.AkmenaCoreABI, client: this.publicClient });
        const key = modules_1.MODULE_KEYS[moduleName];
        const [addr, isEnabled, version] = await core.read.getModule([key]);
        if (!isEnabled || addr === "0x0000000000000000000000000000000000000000") {
            throw new errors_1.ModuleUnavailableError(moduleName);
        }
        this.addressCache[moduleName] = { address: addr, enabled: isEnabled, version };
        return addr;
    }
    async hasModule(moduleName) {
        try {
            await this.resolveModule(moduleName);
            return true;
        }
        catch {
            return false;
        }
    }
    listCachedModules() {
        return { ...this.addressCache };
    }
    invalidateCache() {
        this.addressCache = {};
        this.versionVerified = false;
    }
    async health() {
        const core = (0, viem_1.getContract)({ address: this.coreAddress, abi: AkmenaCore_1.AkmenaCoreABI, client: this.publicClient });
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
exports.AkmenaClient = AkmenaClient;
//# sourceMappingURL=AkmenaClient.js.map