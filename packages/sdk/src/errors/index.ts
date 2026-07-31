export class AkmenaError extends Error {
    constructor(public code: string, message: string, public receipt?: any) {
        super(message);
        this.name = "AkmenaError";
    }
}

export class AuthorizationError extends AkmenaError {
    constructor(message: string = "Caller is not authorized to perform this action.") {
        super("UNAUTHORIZED", message);
        this.name = "AuthorizationError";
    }
}

export function translateContractError(err: any): never {
    const errorString = err.message || err.toString();
    if (errorString.includes("Unauthorized") || errorString.includes("UnauthorizedInitiator")) {
        throw new AuthorizationError();
    }
    // Fallback
    throw new AkmenaError("CONTRACT_REVERT", "Transaction reverted: " + errorString);
}
