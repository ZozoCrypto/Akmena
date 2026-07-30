// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IPaymentsEngine} from "./IPaymentsEngine.sol";
import {LibStorage} from "../storage/LibStorage.sol";

contract PaymentsEngine is IPaymentsEngine {
    function executePayment(address from, address to, uint256 amount) external override {
        if (from == address(0) || to == address(0)) revert InvalidAddress();
        if (amount == 0) revert InvalidAmount();

        LibStorage.PaymentsStorage storage ds = LibStorage.payments();
        
        // M2M State Update for volume tracking (decoupled from standard logic to protect privacy)
        ds.totalProcessedVolume += amount;

        // Note: Future integration point for hybrid ERC-8109 transient storage execution
        emit PaymentExecuted(from, to, amount);
    }

    function getTotalVolume() external view override returns (uint256) {
        return LibStorage.payments().totalProcessedVolume;
    }
}
