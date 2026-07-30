// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IPaymentsEngine {
    event PaymentExecuted(address indexed from, address indexed to, uint256 amount);

    error InvalidAddress();
    error InvalidAmount();
    error PaymentFailed();

    function executePayment(address from, address to, uint256 amount) external;
    function getTotalVolume() external view returns (uint256);
}
