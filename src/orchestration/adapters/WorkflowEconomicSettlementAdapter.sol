// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ISettlementModule, ProtocolContext} from "../IWorkflowEngine.sol";

import {IEconomicCommitmentEngine} from "../../economics/IEconomicCommitmentEngine.sol";

/**
 * @title WorkflowEconomicSettlementAdapter
 * @notice Strict Workflow boundary for the lower-level economic settlement primitive.
 *
 * Dependency direction:
 *
 *     WorkflowEngine
 *          ↓
 *     This Adapter
 *          ↓
 *     EconomicCommitmentEngine
 *
 * The EconomicCommitmentEngine does not know this adapter exists and
 * does not import anything from the orchestration layer.
 */
contract WorkflowEconomicSettlementAdapter is ISettlementModule {
    error InvalidWorkflowCaller();
    error InvalidSettlementData();
    error InvalidDependency();

    address public immutable workflowEngine;
    IEconomicCommitmentEngine public immutable economicEngine;

    constructor(address workflowEngine_, address economicEngine_) {
        if (
            workflowEngine_ == address(0) || workflowEngine_.code.length == 0 || economicEngine_ == address(0)
                || economicEngine_.code.length == 0
        ) {
            revert InvalidDependency();
        }

        workflowEngine = workflowEngine_;
        economicEngine = IEconomicCommitmentEngine(economicEngine_);
    }

    function executeSettlement(bytes32 escrowId, bytes calldata data, ProtocolContext calldata ctx) external override {
        if (msg.sender != workflowEngine) {
            revert InvalidWorkflowCaller();
        }

        if (data.length != 32) {
            revert InvalidSettlementData();
        }

        bytes32 commitmentId = abi.decode(data, (bytes32));

        economicEngine.finalizeSettlement(uint256(escrowId), commitmentId);

        ctx;
    }
}
