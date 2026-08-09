// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {WorkflowEngine} from "../../../src/orchestration/WorkflowEngine.sol";

contract WorkflowHandler is Test {
    WorkflowEngine public immutable engine;
    
    bytes32[] public workflowIds;
    mapping(bytes32 => address) public workflowInitiator;
    mapping(bytes32 => bool) public isAdvanced;

    uint256 public initializeCount;
    uint256 public advanceCount;
    uint256 public unauthorizedAdvanceAttempts;
    uint256 public unauthorizedAdvanceSuccesses;

    constructor(WorkflowEngine _engine) {
        engine = _engine;
    }

    function initializeWorkflow(address initiator, bytes32 agentId, bytes32 agreementId, bytes32 escrowId) external {
        initiator = _nonZero(initiator);
        agentId = agentId == bytes32(0) ? keccak256("default.agent") : agentId;
        agreementId = agreementId == bytes32(0) ? keccak256("default.agreement") : agreementId;
        escrowId = escrowId == bytes32(0) ? keccak256("default.escrow") : escrowId;

        vm.prank(initiator);
        try engine.initializeWorkflow(agentId, agreementId, escrowId) returns (bytes32 id) {
            if (id != bytes32(0) && workflowInitiator[id] == address(0)) {
                workflowIds.push(id);
                workflowInitiator[id] = initiator;
                initializeCount++;
            }
        } catch {}
    }

    function advanceWorkflow(address caller, uint256 index, bytes calldata settlementData, bytes calldata memoryData, bytes calldata reputationData) external {
        if (workflowIds.length == 0) return;
        bytes32 id = workflowIds[index % workflowIds.length];
        address trueInitiator = workflowInitiator[id];

        caller = _nonZero(caller);

        vm.prank(caller);
        try engine.advanceToCompletion(id, settlementData, memoryData, reputationData) {
            advanceCount++;
            isAdvanced[id] = true;
            if (caller != trueInitiator) {
                unauthorizedAdvanceSuccesses++;
            }
        } catch {
            if (caller != trueInitiator) {
                unauthorizedAdvanceAttempts++;
            }
        }
    }

    function workflowIdsLength() external view returns (uint256) {
        return workflowIds.length;
    }

    function _nonZero(address value) internal pure returns (address) {
        return value == address(0) ? address(1) : value;
    }
}
