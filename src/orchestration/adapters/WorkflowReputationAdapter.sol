// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IReputationModule, ProtocolContext} from "../IWorkflowEngine.sol";
import {IReputationEngine} from "../../reputation/IReputationEngine.sol";

/// @title WorkflowReputationAdapter
/// @notice Adapts the primitive ReputationEngine to the Workflow interface.
/// @dev The authorized Workflow actor is the reputation subject.
contract WorkflowReputationAdapter is IReputationModule {
    error InvalidWorkflowEngine();
    error InvalidReputationEngine();
    error UnauthorizedWorkflow();
    error InvalidReputationData();

    address public immutable workflowEngine;
    IReputationEngine public immutable reputationEngine;

    constructor(address workflowEngine_, address reputationEngine_) {
        if (workflowEngine_ == address(0) || workflowEngine_.code.length == 0) {
            revert InvalidWorkflowEngine();
        }

        if (reputationEngine_ == address(0) || reputationEngine_.code.length == 0) {
            revert InvalidReputationEngine();
        }

        workflowEngine = workflowEngine_;
        reputationEngine = IReputationEngine(reputationEngine_);
    }

    function updateReputation(uint256 identityId, bytes calldata data, ProtocolContext calldata ctx) external override {
        if (msg.sender != workflowEngine) {
            revert UnauthorizedWorkflow();
        }

        if (data.length != 32) {
            revert InvalidReputationData();
        }

        uint256 score = abi.decode(data, (uint256));
        reputationEngine.updateScore(ctx.actor, score);

        identityId;
    }
}
