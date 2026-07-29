// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IVerificationEngine} from "./IVerificationEngine.sol";
import {LibStorage} from "../storage/LibStorage.sol";

contract VerificationEngine is IVerificationEngine {
    function setVerification(address identity, bool status) external override {
        if (identity == address(0)) revert InvalidAddress();

        LibStorage.AuthorizationStorage storage ds = LibStorage.authorization();
        ds.verified[identity] = status;

        emit IdentityVerified(identity, status);
    }

    function isVerified(address identity) external view override returns (bool) {
        if (identity == address(0)) return false;

        LibStorage.AuthorizationStorage storage ds = LibStorage.authorization();
        return ds.verified[identity];
    }
}
