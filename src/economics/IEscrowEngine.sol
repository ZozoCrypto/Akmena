// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {LibStorage} from "../storage/LibStorage.sol";

interface IEscrowEngine {
    event EscrowCreated(uint256 indexed escrowId, address indexed buyer, address indexed seller, uint256 amount);
    event EscrowReleased(uint256 indexed escrowId);
    event EscrowRefunded(uint256 indexed escrowId);

    error InvalidAddress();
    error InvalidAmount();
    error EscrowNotFound();
    error EscrowNotActive();
    error UnauthorizedAccess();

    function createEscrow(address buyer, address seller, uint256 amount) external returns (uint256);
    function releaseEscrow(uint256 escrowId) external;
    function refundEscrow(uint256 escrowId) external;
    function getEscrow(uint256 escrowId) external view returns (LibStorage.EscrowData memory);
}
