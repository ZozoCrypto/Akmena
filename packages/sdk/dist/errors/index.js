"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.translateContractError = exports.UnsupportedProtocolVersionError = exports.ModuleUnavailableError = exports.WorkflowError = exports.CapabilityError = exports.AuthorizationError = exports.AkmenaError = void 0;
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
function translateContractError(err) {
    const msg = err.message || err.toString();
    if (msg.includes("Unauthorized") || msg.includes("UnauthorizedInitiator"))
        throw new AuthorizationError();
    if (msg.includes("InvalidWorkflowState"))
        throw new WorkflowError();
    throw new AkmenaError("CONTRACT_REVERT", "Transaction reverted: " + msg, err);
}
exports.translateContractError = translateContractError;
//# sourceMappingURL=index.js.map