// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IMemoryModule, ProtocolContext} from "../IWorkflowEngine.sol";
import {IMemoryEngine} from "../../memory/IMemoryEngine.sol";

/// @title WorkflowMemoryAdapter
/// @notice Adapts the primitive MemoryEngine to the Workflow memory interface.
/// @dev Workflow remains the authorization boundary; MemoryEngine remains a
///      lower-layer primitive and knows nothing about Workflow.
contract WorkflowMemoryAdapter is IMemoryModule {
    error InvalidWorkflowEngine();
    error InvalidMemoryEngine();
    error UnauthorizedWorkflow();
    error InvalidMemoryData();

    address public immutable workflowEngine;
    IMemoryEngine public immutable memoryEngine;

    constructor(address workflowEngine_, address memoryEngine_) {
        if (workflowEngine_ == address(0) || workflowEngine_.code.length == 0) {
            revert InvalidWorkflowEngine();
        }

        if (memoryEngine_ == address(0) || memoryEngine_.code.length == 0) {
            revert InvalidMemoryEngine();
        }

        workflowEngine = workflowEngine_;
        memoryEngine = IMemoryEngine(memoryEngine_);
    }

    function commitMemory(uint256 identityId, bytes calldata data, ProtocolContext calldata ctx) external override {
        if (msg.sender != workflowEngine) {
            revert UnauthorizedWorkflow();
        }

        if (data.length != 32) {
            revert InvalidMemoryData();
        }

        bytes32 rootHash = abi.decode(data, (bytes32));
        memoryEngine.commitRoot(bytes32(identityId), rootHash);

        ctx;
    }
}
