// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IAkmenaEscrow {
    enum Status { NONE, ACTIVE, COMPLETED, REFUNDED, DISPUTED }

    struct Task {
        address buyer;
        address seller;
        address arbiter;
        uint256 amount;
        uint256 deadline;
        Status status;
    }

    event TaskCreated(bytes32 indexed taskId, address indexed buyer, address indexed seller, uint256 amount);
    event TaskCompleted(bytes32 indexed taskId, address indexed seller);
    event TaskRefunded(bytes32 indexed taskId, address indexed buyer);
    event TaskDisputed(bytes32 indexed taskId, address indexed winner);

    function releaseFunds(bytes32 taskId) external;
    function claimRefund(bytes32 taskId) external;
    function resolveDispute(bytes32 taskId, address winner) external;
    function getTask(bytes32 taskId) external view returns (Task memory);
}