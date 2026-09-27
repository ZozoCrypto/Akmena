// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {WorkflowEngine} from "../../../src/orchestration/WorkflowEngine.sol";

contract WorkflowHandler is Test {
    WorkflowEngine public immutable engine;

    uint256 public immutable identityId;
    address public immutable identityOwner;

    bytes32[] public workflowIds;
    mapping(bytes32 => address) public workflowInitiator;
    mapping(bytes32 => bool) public isAdvanced;

    uint256 public initializeCount;
    uint256 public advanceCount;
    uint256 public unauthorizedAdvanceAttempts;
    uint256 public unauthorizedAdvanceSuccesses;

    constructor(WorkflowEngine _engine, uint256 _identityId, address _identityOwner) {
        engine = _engine;
        identityId = _identityId;
        identityOwner = _identityOwner;
    }

    function initializeWorkflow(address initiator, uint256 requestedIdentityId, bytes32 agreementId, bytes32 escrowId)
        external
    {
        initiator = _nonZero(initiator);

        if (agreementId == bytes32(0)) {
            agreementId = keccak256("default.agreement");
        }

        if (escrowId == bytes32(0)) {
            escrowId = keccak256("default.escrow");
        }

        // Fuzz the identity argument, but keep the canonical valid identity
        // available as a deterministic success path.
        uint256 id = requestedIdentityId;

        vm.prank(initiator);

        try engine.initializeWorkflow(id, agreementId, escrowId) returns (bytes32 workflowId) {
            if (workflowId != bytes32(0) && workflowInitiator[workflowId] == address(0)) {
                workflowIds.push(workflowId);
                workflowInitiator[workflowId] = initiator;
                initializeCount++;
            }
        } catch {}
    }

    function initializeValidWorkflow(bytes32 agreementId, bytes32 escrowId) external {
        if (agreementId == bytes32(0)) {
            agreementId = keccak256("default.agreement");
        }

        if (escrowId == bytes32(0)) {
            escrowId = keccak256("default.escrow");
        }

        vm.prank(identityOwner);

        try engine.initializeWorkflow(identityId, agreementId, escrowId) returns (bytes32 workflowId) {
            if (workflowId != bytes32(0) && workflowInitiator[workflowId] == address(0)) {
                workflowIds.push(workflowId);
                workflowInitiator[workflowId] = identityOwner;
                initializeCount++;
            }
        } catch {}
    }

    function advanceWorkflow(
        address caller,
        uint256 index,
        bytes calldata settlementData,
        bytes calldata memoryData,
        bytes calldata reputationData
    ) external {
        if (workflowIds.length == 0) {
            return;
        }

        bytes32 workflowId = workflowIds[index % workflowIds.length];

        caller = _nonZero(caller);

        vm.prank(caller);

        try engine.advanceToCompletion(workflowId, settlementData, memoryData, reputationData) {
            advanceCount++;
            isAdvanced[workflowId] = true;

            // Under the new model, a caller may legitimately be different
            // from the original initiator if authorized for the Identity.
            if (caller != identityOwner) {
                unauthorizedAdvanceSuccesses++;
            }
        } catch {
            if (caller != identityOwner) {
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
