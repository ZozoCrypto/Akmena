// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaGovernor} from "../../src/governance/AkmenaGovernor.sol";
import {AkmenaTimelock} from "../../src/governance/AkmenaTimelock.sol";
import {ProtocolAction, ActionType, ProposalState, IVotes} from "../../src/governance/IGovernance.sol";

contract MockToken is IVotes {
    mapping(address => uint256) public votes;
    uint256 public totalTokens = 100_000_000 * 10**18;

    function setVotes(address account, uint256 amount) external {
        votes[account] = amount;
    }

    function getPastVotes(address account, uint256) external view override returns (uint256) {
        return votes[account];
    }

    function totalSupply() external view override returns (uint256) {
        return totalTokens;
    }
}

contract MockAkmenaCore {
    event ActionExecuted(ActionType action, bytes payload);

    function executeGovernanceAction(ActionType action, bytes calldata payload) external {
        emit ActionExecuted(action, payload);
    }
}

contract GovernanceIntegrationTest is Test {
    AkmenaGovernor public governor;
    AkmenaTimelock public timelock;
    MockToken public token;
    MockAkmenaCore public core;

    address public proposer = address(0x1);
    address public voter1 = address(0x2);
    address public guardian = address(0x3);

    bytes32 public constant ADR_HASH = keccak256("ADR-007-GOVERNANCE-SPEC");

    function setUp() public {
        token = new MockToken();
        core = new MockAkmenaCore();

        governor = new AkmenaGovernor(address(token));
        timelock = new AkmenaTimelock(address(governor), address(core), guardian);
        governor.setTimelock(address(timelock));

        // Fund proposer & voter
        token.setVotes(proposer, 2_000_000 * 10**18); // > 1M threshold
        token.setVotes(voter1, 5_000_000 * 10**18);   // > 4% quorum
    }

    function test_FullProposalLifecycle() public {
        ProtocolAction[] memory actions = new ProtocolAction[](1);
        actions[0] = ProtocolAction({
            actionType: ActionType.REGISTER_MODULE,
            payload: abi.encode(address(0x99), keccak256("test.module"))
        });

        vm.prank(proposer);
        bytes32 propId = governor.propose(actions, "Upgrade Module", "ipfs://Qmdoc", ADR_HASH);

        // Move to Active state
        vm.roll(block.number + 2);
        assertEq(uint(governor.state(propId)), uint(ProposalState.Active));

        // Vote YES
        vm.prank(voter1);
        governor.castVote(propId, true);

        // Advance blocks past voting period
        vm.roll(block.number + 50401);
        assertEq(uint(governor.state(propId)), uint(ProposalState.Succeeded));

        // Queue
        governor.queue(propId);
        assertEq(uint(governor.state(propId)), uint(ProposalState.Queued));

        // Fast forward through 3-day timelock
        vm.warp(block.timestamp + 3 days + 1);

        // Execute via Timelock -> MockCore
        vm.expectEmit(true, true, true, true);
        emit MockAkmenaCore.ActionExecuted(actions[0].actionType, actions[0].payload);
        timelock.execute(propId, actions, ADR_HASH);

        assertEq(uint(governor.state(propId)), uint(ProposalState.Executed));
    }

    function test_GuardianCanVetoQueuedProposal() public {
        ProtocolAction[] memory actions = new ProtocolAction[](0);

        vm.prank(proposer);
        bytes32 propId = governor.propose(actions, "Bad Upgrade", "ipfs://QmBad", ADR_HASH);

        vm.roll(block.number + 2);
        vm.prank(voter1);
        governor.castVote(propId, true);

        vm.roll(block.number + 50401);
        governor.queue(propId);

        // Guardian Vetoes
        vm.prank(guardian);
        timelock.cancel(propId);

        assertEq(uint(governor.state(propId)), uint(ProposalState.Canceled));
    }
}
