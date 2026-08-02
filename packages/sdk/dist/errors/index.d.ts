export declare class AkmenaError extends Error {
    code: string;
    metadata?: any;
    constructor(code: string, message: string, metadata?: any);
}
export declare class AuthorizationError extends AkmenaError {
    constructor(message?: string);
}
export declare class CapabilityError extends AkmenaError {
    constructor(message?: string);
}
export declare class WorkflowError extends AkmenaError {
    constructor(message?: string);
}
export declare class ModuleUnavailableError extends AkmenaError {
    constructor(moduleKey: string);
}
export declare class UnsupportedProtocolVersionError extends AkmenaError {
    constructor(expected: string, actual: string);
}
export declare function translateContractError(err: any): never;
