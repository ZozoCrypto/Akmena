export declare const EscrowEngineABI: readonly [{
    readonly type: "function";
    readonly name: "createEscrow";
    readonly inputs: readonly [{
        readonly name: "escrowId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "payee";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "payable";
}, {
    readonly type: "function";
    readonly name: "exists";
    readonly inputs: readonly [{
        readonly name: "escrowId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bool";
        readonly internalType: "bool";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getEscrow";
    readonly inputs: readonly [{
        readonly name: "escrowId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "tuple";
        readonly internalType: "struct IEscrowEngine.Escrow";
        readonly components: readonly [{
            readonly name: "id";
            readonly type: "bytes32";
            readonly internalType: "bytes32";
        }, {
            readonly name: "payer";
            readonly type: "address";
            readonly internalType: "address";
        }, {
            readonly name: "payee";
            readonly type: "address";
            readonly internalType: "address";
        }, {
            readonly name: "amount";
            readonly type: "uint256";
            readonly internalType: "uint256";
        }, {
            readonly name: "released";
            readonly type: "bool";
            readonly internalType: "bool";
        }, {
            readonly name: "refunded";
            readonly type: "bool";
            readonly internalType: "bool";
        }];
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "refund";
    readonly inputs: readonly [{
        readonly name: "escrowId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "release";
    readonly inputs: readonly [{
        readonly name: "escrowId";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "event";
    readonly name: "EscrowCreated";
    readonly inputs: readonly [{
        readonly name: "escrowId";
        readonly type: "bytes32";
        readonly indexed: true;
        readonly internalType: "bytes32";
    }, {
        readonly name: "payer";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "payee";
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
        readonly type: "bytes32";
        readonly indexed: true;
        readonly internalType: "bytes32";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "EscrowReleased";
    readonly inputs: readonly [{
        readonly name: "escrowId";
        readonly type: "bytes32";
        readonly indexed: true;
        readonly internalType: "bytes32";
    }];
    readonly anonymous: false;
}, {
    readonly type: "error";
    readonly name: "EscrowAlreadyExists";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "EscrowAlreadyRefunded";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "EscrowAlreadyReleased";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "EscrowNotFound";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "InvalidAmount";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "InvalidPayee";
    readonly inputs: readonly [];
}];
