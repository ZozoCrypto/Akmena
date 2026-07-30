// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {LibStorage} from "../storage/LibStorage.sol";

interface ISettlementEngine {
    event SettlementRecorded(bytes32 indexed settlementId, address indexed payer, address indexed payee, uint256 amount);

    error InvalidAddress();
    error InvalidAmount();
    error SettlementAlreadyExists();
    error SettlementNotFound();

    function recordSettlement(bytes32 settlementId, address payer, address payee, uint256 amount) external;
    function getSettlement(bytes32 settlementId) external view returns (LibStorage.SettlementData memory);
    function exists(bytes32 settlementId) external view returns (bool);
}
