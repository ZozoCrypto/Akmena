// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IDelegationEngine} from "./IDelegationEngine.sol";
import {LibStorage} from "../storage/LibStorage.sol";

contract DelegationEngine is IDelegationEngine {
    function setDelegate(address delegate, bool status) external override {
        if (delegate == address(0)) revert InvalidAddress();

        LibStorage.AuthorizationStorage storage ds = LibStorage.authorization();
        ds.delegates[msg.sender][delegate] = status;

        emit DelegateSet(msg.sender, delegate, status);
    }

    function isDelegate(address identity, address delegate) external view override returns (bool) {
        if (identity == address(0) || delegate == address(0)) return false;

        LibStorage.AuthorizationStorage storage ds = LibStorage.authorization();
        return ds.delegates[identity][delegate];
    }
}
