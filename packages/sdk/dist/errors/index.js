"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.translateContractError = exports.UnsupportedProtocolVersionError = exports.ModuleUnavailableError = exports.WorkflowError = exports.CapabilityError = exports.AuthorizationError = exports.AkmenaError = void 0;
const viem_1 = require("viem");
const AkmenaCore_1 = require("../abis/AkmenaCore");
const AgentRegistry_1 = require("../abis/AgentRegistry");
const EscrowEngine_1 = require("../abis/EscrowEngine");
const PaymentsEngine_1 = require("../abis/PaymentsEngine");
class AkmenaError extends Error {
    code;
    metadata;
    constructor(code, message, metadata) {
        super(message);
        this.code = code;
        this.metadata = metadata;
        this.name = "AkmenaError";
    }
}
exports.AkmenaError = AkmenaError;
class AuthorizationError extends AkmenaError {
    constructor(message = "Caller is not authorized.") { super("UNAUTHORIZED", message); this.name = "AuthorizationError"; }
}
exports.AuthorizationError = AuthorizationError;
class CapabilityError extends AkmenaError {
    constructor(message = "Agent lacks required capability.") { super("CAPABILITY_MISSING", message); this.name = "CapabilityError"; }
}
exports.CapabilityError = CapabilityError;
class WorkflowError extends AkmenaError {
    constructor(message = "Invalid workflow state transition.") { super("INVALID_WORKFLOW_STATE", message); this.name = "WorkflowError"; }
}
exports.WorkflowError = WorkflowError;
class ModuleUnavailableError extends AkmenaError {
    constructor(moduleKey) { super("MODULE_UNAVAILABLE", `Module ${moduleKey} is not registered or disabled.`); this.name = "ModuleUnavailableError"; }
}
exports.ModuleUnavailableError = ModuleUnavailableError;
class UnsupportedProtocolVersionError extends AkmenaError {
    constructor(expected, actual) { super("UNSUPPORTED_VERSION", `SDK requires protocol v${expected}. Found v${actual}`); this.name = "UnsupportedProtocolVersionError"; }
}
exports.UnsupportedProtocolVersionError = UnsupportedProtocolVersionError;
// Master ABI registry for decoding custom Solidity errors deterministically
const MASTER_ABIS = [
    ...AkmenaCore_1.AkmenaCoreABI,
    ...AgentRegistry_1.AgentRegistryABI,
    ...EscrowEngine_1.EscrowEngineABI,
    ...PaymentsEngine_1.PaymentsEngineABI
];
function translateContractError(err) {
    // Extract raw hex revert data from Viem simulation/transaction errors
    const errorData = err?.data?.data || err?.data || err?.cause?.data;
    if (errorData && typeof errorData === 'string' && errorData.startsWith('0x')) {
        try {
            const decoded = (0, viem_1.decodeErrorResult)({
                abi: MASTER_ABIS,
                data: errorData
            });
            const errorName = decoded.errorName;
            // Map known custom Solidity errors to typed SDK exceptions
            if (errorName.includes("Unauthorized")) {
                throw new AuthorizationError(`Contract revert: ${errorName}`);
            }
            if (errorName.includes("InvalidState") || errorName.includes("Expired")) {
                throw new WorkflowError(`Contract revert: ${errorName}`);
            }
            throw new AkmenaError(errorName, `Smart contract execution reverted with custom error: ${errorName}`, decoded.args);
        }
        catch (decodeErr) {
            // If it's already one of our typed AkmenaErrors, rethrow it
            if (decodeErr instanceof AkmenaError)
                throw decodeErr;
            // Otherwise fall through to string fallback
        }
    }
    // Fallback string matching for standard Error(string) reverts or network errors
    const msg = err.message || err.toString();
    if (msg.includes("Unauthorized") || msg.includes("UnauthorizedInitiator"))
        throw new AuthorizationError();
    if (msg.includes("InvalidWorkflowState"))
        throw new WorkflowError();
    throw new AkmenaError("CONTRACT_REVERT", "Transaction reverted: " + msg, err);
}
exports.translateContractError = translateContractError;
//# sourceMappingURL=index.js.map