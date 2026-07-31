// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {WorkflowStep} from "../orchestration/IWorkflowEngine.sol";

library LibWorkflowStorage {
    bytes32 internal constant WORKFLOW_STORAGE_POSITION =
        keccak256(abi.encode(uint256(keccak256("akmena.storage.workflow")) - 1)) & ~bytes32(uint256(31));

    struct WorkflowRecord {
        bytes32 workflowId;
        address initiator;
        bytes32 agentIdentityId;
        bytes32 agreementId;
        bytes32 escrowId;
        WorkflowStep currentStep; // Strict state machine tracking
    }

    struct WorkflowStorage {
        mapping(bytes32 => WorkflowRecord) workflows;
    }

    function workflowStorage() internal pure returns (WorkflowStorage storage ws) {
        bytes32 position = WORKFLOW_STORAGE_POSITION;
        assembly {
            ws.slot := position
        }
    }
}
