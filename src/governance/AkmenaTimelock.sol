// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ActionType, ProtocolAction, IAkmenaCoreExecutable, IAkmenaTimelock} from "./IGovernance.sol";

contract AkmenaTimelock is IAkmenaTimelock {
    address public immutable governor;
    address public immutable akmenaCore;
    
    address public guardian;
    bool public guardianSunset;
    uint256 public constant GRACE_PERIOD = 14 days;

    struct TimelockRecord {
        uint256 eta;
        bytes32 proposalHash;
        bool executed;
        bool canceled;
    }
    mapping(bytes32 => TimelockRecord) public records;

    event ProposalQueued(bytes32 indexed proposalId, uint256 eta);
    event ProposalExecuted(bytes32 indexed proposalId);
    event ProposalCanceled(bytes32 indexed proposalId);
    event GuardianSunsetExecuted();

    error Unauthorized();
    error NotQueued();
    error TimelockNotExpired();
    error TimelockExpired();
    error ProposalAlreadyExecuted();
    error InvalidProposalHash();
    error GuardianSunset();

    constructor(address _governor, address _akmenaCore, address _guardian) {
        governor = _governor;
        akmenaCore = _akmenaCore;
        guardian = _guardian;
    }

    modifier onlyGovernor() {
        if (msg.sender != governor) revert Unauthorized();
        _;
    }

    function queue(bytes32 proposalId, uint256 eta, bytes32 proposalHash) external override onlyGovernor {
        records[proposalId] = TimelockRecord({
            eta: eta,
            proposalHash: proposalHash,
            executed: false,
            canceled: false
        });
        emit ProposalQueued(proposalId, eta);
    }

    function cancel(bytes32 proposalId) external override {
        if (guardianSunset) revert GuardianSunset();
        if (msg.sender != guardian) revert Unauthorized();
        
        TimelockRecord storage r = records[proposalId];
        if (r.eta == 0) revert NotQueued();
        if (r.executed) revert ProposalAlreadyExecuted();
        
        r.canceled = true;
        r.eta = 0;
        emit ProposalCanceled(proposalId);
    }

    function sunsetGuardian() external {
        if (msg.sender != guardian) revert Unauthorized();
        guardianSunset = true;
        guardian = address(0);
        emit GuardianSunsetExecuted();
    }

    function execute(bytes32 proposalId, ProtocolAction[] calldata actions, bytes32 adrHash) external override {
        TimelockRecord storage r = records[proposalId];
        
        if (r.executed) revert ProposalAlreadyExecuted();
        if (r.eta == 0 || r.canceled) revert NotQueued();
        if (block.timestamp < r.eta) revert TimelockNotExpired();
        if (block.timestamp > r.eta + GRACE_PERIOD) revert TimelockExpired();

        bytes32 computedHash = keccak256(abi.encode(actions, adrHash));
        if (computedHash != r.proposalHash) revert InvalidProposalHash();

        r.executed = true;
        r.eta = 0;

        for (uint256 i = 0; i < actions.length; i++) {
            IAkmenaCoreExecutable(akmenaCore).executeGovernanceAction(
                actions[i].actionType,
                actions[i].payload
            );
        }

        emit ProposalExecuted(proposalId);
    }

    function getProposalStatus(bytes32 proposalId) external view override returns (uint256 eta, bool executed, bool canceled) {
        TimelockRecord memory r = records[proposalId];
        return (r.eta, r.executed, r.canceled);
    }
}
