// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaToken} from "../../../src/token/core/AkmenaToken.sol";

contract TokenHandler is Test {
    AkmenaToken public immutable token;
    address public immutable initialHolder;

    uint256 public transferCount;
    uint256 public failedTransfers;

    constructor(AkmenaToken _token, address _initialHolder) {
        token = _token;
        initialHolder = _initialHolder;
    }

    function transfer(address recipient, uint256 amount) external {
        recipient = recipient == address(0) ? address(0x1) : recipient;
        
        uint256 holderBalance = token.balanceOf(initialHolder);
        amount = bound(amount, 0, holderBalance);

        vm.prank(initialHolder);
        try token.transfer(recipient, amount) {
            transferCount++;
        } catch {
            failedTransfers++;
        }
    }
}
