import { decodeErrorResult, Hex } from 'viem';
import { AkmenaCoreABI } from '../abis/AkmenaCore';
import { AgentRegistryABI } from '../abis/AgentRegistry';
import { EscrowEngineABI } from '../abis/EscrowEngine';
import { PaymentsEngineABI } from '../abis/PaymentsEngine';

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

// Master ABI registry for decoding custom Solidity errors deterministically
const MASTER_ABIS = [
    ...AkmenaCoreABI,
    ...AgentRegistryABI,
    ...EscrowEngineABI,
    ...PaymentsEngineABI
] as const;

export function translateContractError(err: any): never {
    // Extract raw hex revert data from Viem simulation/transaction errors
    const errorData = err?.data?.data || err?.data || err?.cause?.data;

    if (errorData && typeof errorData === 'string' && errorData.startsWith('0x')) {
        try {
            const decoded = decodeErrorResult({
                abi: MASTER_ABIS,
                data: errorData as Hex
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
        } catch (decodeErr: any) {
            // If it's already one of our typed AkmenaErrors, rethrow it
            if (decodeErr instanceof AkmenaError) throw decodeErr;
            // Otherwise fall through to string fallback
        }
    }

    // Fallback string matching for standard Error(string) reverts or network errors
    const msg = err.message || err.toString();
    if (msg.includes("Unauthorized") || msg.includes("UnauthorizedInitiator")) throw new AuthorizationError();
    if (msg.includes("InvalidWorkflowState")) throw new WorkflowError();
    
    throw new AkmenaError("CONTRACT_REVERT", "Transaction reverted: " + msg, err);
}
