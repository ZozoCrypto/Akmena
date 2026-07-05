// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC1363Receiver} from "../token/interfaces/IERC1363Receiver.sol";
import {IAkmenaToken} from "../token/interfaces/IAkmenaToken.sol";
import {IAkmenaEscrow} from "./interfaces/IAkmenaEscrow.sol";
import {EscrowErrors} from "./lib/EscrowErrors.sol";

contract AkmenaEscrow is IAkmenaEscrow, IERC1363Receiver {
    IAkmenaToken public immutable token;
    mapping(bytes32 => Task) public tasks;

 uint256 public constant GRACE_PERIOD = 5 minutes;
    uint256 public constant MAX_TASK_DURATION = 30 days;

    constructor(address _token) { token = IAkmenaToken(_token); }

    function onTransferReceived(address, address from, uint256 value, bytes calldata data) external override returns (bytes4) {
        if (msg.sender != address(token)) revert EscrowErrors.UntrustedToken();

        (bytes32 taskId, address seller, address arbiter, uint256 duration) = abi.decode(
            data, (bytes32, address, address, uint256)
        );

        if (tasks[taskId].status != Status.NONE) revert EscrowErrors.TaskAlreadyExists();
        
        // forge-ignore-warning block-timestamp
        if (duration == 0 || duration > MAX_TASK_DURATION) revert EscrowErrors.InvalidTaskData();

        tasks[taskId] = Task({
            buyer: from,
            seller: seller,
            arbiter: arbiter,
            amount: value,
            createdAt: block.timestamp,
            duration: duration,
            status: Status.ACTIVE
        });

        emit TaskCreated(taskId, from, seller, value);
        return IERC1363Receiver.onTransferReceived.selector;
    }

    function releaseFunds(bytes32 taskId) external {
        Task storage task = tasks[taskId];
        if (task.status != Status.ACTIVE) revert EscrowErrors.TaskNotActive();
        if (msg.sender != task.arbiter) revert EscrowErrors.UnauthorizedArbiter();

        task.status = Status.COMPLETED;
        emit TaskCompleted(taskId, task.seller);
        require(token.transfer(task.seller, task.amount), "Transfer Failed");
    }

    function claimRefund(bytes32 taskId) external {
        Task storage task = tasks[taskId];
        if (task.status != Status.ACTIVE) revert EscrowErrors.TaskNotActive();

        // forge-ignore-warning block-timestamp
        if (block.timestamp < (task.createdAt + task.duration + GRACE_PERIOD)) revert EscrowErrors.DeadlineNotPassed();

        task.status = Status.REFUNDED;
        emit TaskRefunded(taskId, task.buyer);
        require(token.transfer(task.buyer, task.amount), "Transfer Failed");
    }

    function resolveDispute(bytes32 taskId, address winner) external {
        Task storage task = tasks[taskId];
        if (task.status != Status.ACTIVE) revert EscrowErrors.TaskNotActive();
        if (msg.sender != task.arbiter) revert EscrowErrors.UnauthorizedArbiter();

        task.status = Status.DISPUTED;
        emit TaskDisputed(taskId, winner);
        require(token.transfer(winner, task.amount), "Transfer Failed");
    }

    function getTask(bytes32 taskId) external view returns (Task memory) {
        return tasks[taskId];
    }
}