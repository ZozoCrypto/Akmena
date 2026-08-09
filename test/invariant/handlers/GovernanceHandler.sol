// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AgentGovernanceEngine} from "../../../src/governance/AgentGovernanceEngine.sol";

contract GovernanceHandler is Test {
    AgentGovernanceEngine public immutable governance;

    bytes32[] public proposalIds;
    mapping(bytes32 => bool) public proposalExists;

    uint256 public createCount;
    uint256 public executeCount;
    uint256 public rejectCount;
    uint256 public duplicateCreateAttempts;
    uint256 public duplicateCreateSuccesses;

    constructor(AgentGovernanceEngine _governance) {
        governance = _governance;
    }

    function createProposal(bytes32 proposalId, string memory description) external {
        proposalId = proposalId == bytes32(0) ? keccak256(abi.encodePacked(block.timestamp, msg.sender, block.prevrandao)) : proposalId;
        bytes memory descBytes = bytes(description);
        if (descBytes.length == 0) {
            description = "Default proposal description";
        }

        bool existsBefore = proposalExists[proposalId];

        try governance.createProposal(proposalId, description) {
            createCount++;
            if (!existsBefore) {
                proposalIds.push(proposalId);
                proposalExists[proposalId] = true;
            } else {
                duplicateCreateSuccesses++;
            }
        } catch {
            if (existsBefore) {
                duplicateCreateAttempts++;
            }
        }
    }

    function executeProposal(uint256 index) external {
        if (proposalIds.length == 0) return;
        bytes32 proposalId = proposalIds[index % proposalIds.length];

        try governance.executeProposal(proposalId) {
            executeCount++;
        } catch {}
    }

    function rejectProposal(uint256 index) external {
        if (proposalIds.length == 0) return;
        bytes32 proposalId = proposalIds[index % proposalIds.length];

        try governance.rejectProposal(proposalId) {
            rejectCount++;
        } catch {}
    }

    function proposalIdsLength() external view returns (uint256) {
        return proposalIds.length;
    }
}
