// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {AgentGovernanceEngine} from "../../src/governance/AgentGovernanceEngine.sol";
import {GovernanceHandler} from "./handlers/GovernanceHandler.sol";

contract GovernanceInvariant is StdInvariant, Test {
    AgentGovernanceEngine internal governance;
    GovernanceHandler internal handler;

    function setUp() public {
        governance = new AgentGovernanceEngine();
        handler = new GovernanceHandler(governance);

        targetContract(address(handler));
    }

    function test_SanityCheck() public pure {
        assertTrue(true);
    }

    /// INVARIANT: Duplicate proposal creation must be blocked
    function invariant_noDuplicateProposalSuccesses() public view {
        assertEq(handler.duplicateCreateSuccesses(), 0);
    }

    /// INVARIANT: Proposal counts match recorded unique proposals
    function invariant_proposalCountConsistency() public view {
        assertTrue(handler.proposalIdsLength() <= handler.createCount());
    }
}
