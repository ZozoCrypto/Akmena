export class AkmenaError extends Error {
    constructor(public code: string, message: string, public metadata?: any) {
        super(message);
        this.name = "AkmenaError";
    }
}

export class AuthorizationError extends AkmenaError {
    constructor(message = "Caller is not authorized.") { super("UNAUTHORIZED", message); this.name = "AuthorizationError"; }
}
export class CapabilityError extends AkmenaError {
    constructor(message = "Agent lacks required capability.") { super("CAPABILITY_MISSING", message); this.name = "CapabilityError"; }
}
export class WorkflowError extends AkmenaError {
    constructor(message = "Invalid workflow state transition.") { super("INVALID_WORKFLOW_STATE", message); this.name = "WorkflowError"; }
}
export class ModuleUnavailableError extends AkmenaError {
    constructor(moduleKey: string) { super("MODULE_UNAVAILABLE", `Module ${moduleKey} is not registered or disabled.`); this.name = "ModuleUnavailableError"; }
}
export class UnsupportedProtocolVersionError extends AkmenaError {
    constructor(expected: string, actual: string) { super("UNSUPPORTED_VERSION", `SDK requires protocol v${expected}. Found v${actual}`); this.name = "UnsupportedProtocolVersionError"; }
}

export function translateContractError(err: any): never {
    const msg = err.message || err.toString();
    if (msg.includes("Unauthorized") || msg.includes("UnauthorizedInitiator")) throw new AuthorizationError();
    if (msg.includes("InvalidWorkflowState")) throw new WorkflowError();
    throw new AkmenaError("CONTRACT_REVERT", "Transaction reverted: " + msg, err);
}
