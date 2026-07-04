// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC1363Receiver} from "../token/interfaces/IERC1363Receiver.sol";
import {IAkmenaToken} from "../token/interfaces/IAkmenaToken.sol";
import {IAkmenaEscrow} from "./interfaces/IAkmenaEscrow.sol";
import {EscrowErrors} from "./lib/EscrowErrors.sol";

/// @title AkmenaEscrow
/// @author Akmena Protocol
/// @notice The trustless M2M agreement layer for the Akmena OS.
contract AkmenaEscrow is IAkmenaEscrow, IERC1363Receiver {
    IAkmenaToken public immutable token;
    mapping(bytes32 => Task) public tasks;

    constructor(address _token) {
        token = IAkmenaToken(_token);
    }

    // ═════════════════════════════════════════════════════════════════════
    // Atomic Task Creation (ERC-1363 Callback)
    // ═════════════════════════════════════════════════════════════════════
    
    /// @notice Triggered automatically when an Agent sends AKM via transferAndCall
    function onTransferReceived(
        address /* operator */,
        address from,
        uint256 value,
        bytes calldata data
    ) external override returns (bytes4) {
        // SECURITY INVARIANT: Only the authentic AKM Kernel can trigger this
        if (msg.sender != address(token)) revert EscrowErrors.UntrustedToken();

        // Decode the machine-readable SLA
        (bytes32 taskId, address seller, address arbiter, uint256 deadline) = abi.decode(
            data, (bytes32, address, address, uint256)
        );

        if (tasks[taskId].status != Status.NONE) revert EscrowErrors.TaskAlreadyExists();
        if (deadline <= block.timestamp) revert EscrowErrors.InvalidTaskData();

        tasks[taskId] = Task({
            buyer: from,
            seller: seller,
            arbiter: arbiter,
            amount: value,
            deadline: deadline,
            status: Status.ACTIVE
        });

        emit TaskCreated(taskId, from, seller, value);
        return IERC1363Receiver.onTransferReceived.selector;
    }

    // ═════════════════════════════════════════════════════════════════════
    // Task Resolution
    // ═════════════════════════════════════════════════════════════════════

    /// @notice Called by the Arbiter when the AI Seller successfully completes the task
    function releaseFunds(bytes32 taskId) external {
        Task storage task = tasks[taskId];
        if (task.status != Status.ACTIVE) revert EscrowErrors.TaskNotActive();
        if (msg.sender != task.arbiter) revert EscrowErrors.UnauthorizedArbiter();

        task.status = Status.COMPLETED;
        emit TaskCompleted(taskId, task.seller);

        require(token.transfer(task.seller, task.amount), "Transfer Failed");
    }

    /// @notice Called by the Buyer if the Seller fails to deliver by the deadline
    function claimRefund(bytes32 taskId) external {
        Task storage task = tasks[taskId];
        if (task.status != Status.ACTIVE) revert EscrowErrors.TaskNotActive();
        if (block.timestamp < task.deadline) revert EscrowErrors.DeadlineNotPassed();

        task.status = Status.REFUNDED;
        emit TaskRefunded(taskId, task.buyer);

        require(token.transfer(task.buyer, task.amount), "Transfer Failed");
    }

    /// @notice Called by the Arbiter to force a resolution (Dispute bypass)
    function resolveDispute(bytes32 taskId, address winner) external {
        Task storage task = tasks[taskId];
        if (task.status != Status.ACTIVE) revert EscrowErrors.TaskNotActive();
        if (msg.sender != task.arbiter) revert EscrowErrors.UnauthorizedArbiter();

        task.status = Status.DISPUTED;
        emit TaskDisputed(taskId, winner);

        require(token.transfer(winner, task.amount), "Transfer Failed");
    }

    // ═════════════════════════════════════════════════════════════════════
    // View Functions
    // ═════════════════════════════════════════════════════════════════════

    function getTask(bytes32 taskId) external view returns (Task memory) {
        return tasks[taskId];
    }
}