// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

enum ProposalState { Pending, Active, Succeeded, Defeated, Queued, Executed, Expired, Canceled }
enum ActionType { REGISTER_MODULE, REMOVE_MODULE, UPDATE_PARAMETER, PAUSE_MODULE, UNPAUSE_MODULE, SET_GOVERNANCE_PARAMETER }

struct ProtocolAction {
    ActionType actionType;
    bytes payload;
}

interface IAkmenaCoreExecutable {
    function executeGovernanceAction(ActionType action, bytes calldata payload) external;
}

interface IAkmenaTimelock {
    function queue(bytes32 proposalId, uint256 eta, bytes32 proposalHash) external;
    function cancel(bytes32 proposalId) external;
    function execute(bytes32 proposalId, ProtocolAction[] calldata actions, bytes32 adrHash) external;
    function getProposalStatus(bytes32 proposalId) external view returns (uint256 eta, bool executed, bool canceled);
}

interface IVotes {
    function getPastVotes(address account, uint256 blockNumber) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}
