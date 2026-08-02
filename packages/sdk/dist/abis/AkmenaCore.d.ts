export declare const AkmenaCoreABI: readonly [{
    readonly type: "constructor";
    readonly inputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "PROTOCOL_VERSION";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "string";
        readonly internalType: "string";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "deployer";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "address";
        readonly internalType: "address";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "getModule";
    readonly inputs: readonly [{
        readonly name: "key";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }];
    readonly outputs: readonly [{
        readonly name: "moduleAddress";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "isEnabled";
        readonly type: "bool";
        readonly internalType: "bool";
    }, {
        readonly name: "version";
        readonly type: "string";
        readonly internalType: "string";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "isPaused";
    readonly inputs: readonly [];
    readonly outputs: readonly [{
        readonly name: "";
        readonly type: "bool";
        readonly internalType: "bool";
    }];
    readonly stateMutability: "view";
}, {
    readonly type: "function";
    readonly name: "registerModule";
    readonly inputs: readonly [{
        readonly name: "key";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "moduleAddress";
        readonly type: "address";
        readonly internalType: "address";
    }, {
        readonly name: "version";
        readonly type: "string";
        readonly internalType: "string";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "setModuleStatus";
    readonly inputs: readonly [{
        readonly name: "key";
        readonly type: "bytes32";
        readonly internalType: "bytes32";
    }, {
        readonly name: "status";
        readonly type: "bool";
        readonly internalType: "bool";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "function";
    readonly name: "setPaused";
    readonly inputs: readonly [{
        readonly name: "status";
        readonly type: "bool";
        readonly internalType: "bool";
    }];
    readonly outputs: readonly [];
    readonly stateMutability: "nonpayable";
}, {
    readonly type: "event";
    readonly name: "ModuleEnabled";
    readonly inputs: readonly [{
        readonly name: "moduleKey";
        readonly type: "bytes32";
        readonly indexed: true;
        readonly internalType: "bytes32";
    }, {
        readonly name: "status";
        readonly type: "bool";
        readonly indexed: false;
        readonly internalType: "bool";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "ModuleRegistered";
    readonly inputs: readonly [{
        readonly name: "moduleKey";
        readonly type: "bytes32";
        readonly indexed: true;
        readonly internalType: "bytes32";
    }, {
        readonly name: "moduleAddress";
        readonly type: "address";
        readonly indexed: true;
        readonly internalType: "address";
    }, {
        readonly name: "version";
        readonly type: "string";
        readonly indexed: false;
        readonly internalType: "string";
    }];
    readonly anonymous: false;
}, {
    readonly type: "event";
    readonly name: "PauseStatusChanged";
    readonly inputs: readonly [{
        readonly name: "paused";
        readonly type: "bool";
        readonly indexed: false;
        readonly internalType: "bool";
    }];
    readonly anonymous: false;
}, {
    readonly type: "error";
    readonly name: "InvalidModuleAddress";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "ModuleAlreadyRegistered";
    readonly inputs: readonly [];
}, {
    readonly type: "error";
    readonly name: "UnauthorizedAccess";
    readonly inputs: readonly [];
}];
