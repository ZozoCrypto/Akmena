"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.MODULE_KEYS = void 0;
const viem_1 = require("viem");
exports.MODULE_KEYS = {
    workflow: (0, viem_1.keccak256)((0, viem_1.toHex)("akmena.module.workflow")),
    settlement: (0, viem_1.keccak256)((0, viem_1.toHex)("akmena.module.settlement")),
    escrow: (0, viem_1.keccak256)((0, viem_1.toHex)("akmena.module.escrow")),
    reputation: (0, viem_1.keccak256)((0, viem_1.toHex)("akmena.module.reputation")),
    memory: (0, viem_1.keccak256)((0, viem_1.toHex)("akmena.module.memory")),
    marketplace: (0, viem_1.keccak256)((0, viem_1.toHex)("akmena.module.marketplace")),
    identity: (0, viem_1.keccak256)((0, viem_1.toHex)("akmena.module.identity"))
};
//# sourceMappingURL=modules.js.map