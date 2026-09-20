export declare const EscrowEngineABI: readonly [{
    readonly type: "constructor";
    readonly inputs: readonly [{
        readonly name: "asset_";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "asset";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "address";
        readonly internalType: "contract IERC20";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "createEscrow";
    readonly inputs: readonly [{
        readonly name: "buyer";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "seller";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "amount";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "referenceId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "createEscrow";
    readonly inputs: readonly [{
        readonly name: "buyer";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "seller";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "amount";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "getEscrow";
    readonly inputs: readonly [{
        readonly name: "escrowId";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "tuple";
        readonly internalType: "struct LibStorage.EscrowData";
        readonly components: readonly [{
            readonly name: "buyer";
            readonly type: "address";
            readonly internalType: "address";
        }, {
            readonly name: "seller";
            readonly type: "address";
            readonly internalType: "address";
        }, {
            readonly name: "amount";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "asset";
            readonly type: "address";
            readonly internalType: "address";
        }, {
            readonly name: "status";
            readonly type: "uint8";
            readonly internalType: "uint8";
        }, {
            readonly name: "referenceId";
            readonly type: "bytes32";
            readonly internalType: "bytes32";
        }];
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "refundEscrow";
    readonly inputs: readonly [{
        readonly name: "escrowId";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "releaseEscrow";
    readonly inputs: readonly [{
        readonly name: "escrowId";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "totalLocked";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "verifyTransientProof";
    readonly inputs: readonly [{
        readonly name: "proofId";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }, {
        readonly name: "operator";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "amount";
        readonly type: "uint256";
        readonly internalType: "uint256";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bool";
        readonly internalType: "bool";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "event";
    readonly name: "EscrowCreated";
    readonly inputs: readonly [{
        readonly name: "escrowId";
        readonly type: "uint256";
        readonly indexed: true;
        readonly internalType: "uint256";
    }, {
        readonly name: "buyer";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "seller";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "amount";
        readonly type: "uint256";
        readonly indexed: false;
        readonly internalType: "uint256";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "EscrowRefunded";
    readonly inputs: readonly [{
        readonly name: "escrowId";
        readonly type: "uint256";
        readonly indexed: true;
        readonly internalType: "uint256";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "EscrowReleased";
    readonly inputs: readonly [{
        readonly name: "escrowId";
        readonly type: "uint256";
        readonly indexed: true;
        readonly internalType: "uint256";
    }];
    readonly anonymous: false;
}, {
    readonly type: "error";
    readonly name: "EscrowNotActive";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "EscrowNotFound";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "EscrowReferenceAlreadyUsed";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "InsufficientEscrowBalance";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "InvalidAddress";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "InvalidAmount";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "SafeERC20FailedOperation";
    readonly inputs: readonly [{
        readonly name: "token";
        readonly type: "address";
        readonly internalType: "address";
    }];
}, {
    readonly type: "error";
    readonly name: "UnauthorizedAccess";
    readonly inputs: readonly [];
}];
