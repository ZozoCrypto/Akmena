// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IAttestationEngine} from "./IAttestationEngine.sol";
import {LibStorage} from "../storage/LibStorage.sol";

contract AttestationEngine is IAttestationEngine {
    function recordAttestation(address subject, bytes32 attestationHash) external override {
        if (subject == address(0)) revert InvalidAddress();
        if (attestationHash == bytes32(0)) revert EmptyAttestation();

        LibStorage.AuthorizationStorage storage ds = LibStorage.authorization();
        ds.attestations[subject][msg.sender][attestationHash] = true;

        emit AttestationRecorded(subject, msg.sender, attestationHash);
    }

    function hasAttestation(address subject, address attester, bytes32 attestationHash) external view override returns (bool) {
        if (subject == address(0) || attester == address(0)) return false;

        LibStorage.AuthorizationStorage storage ds = LibStorage.authorization();
        return ds.attestations[subject][attester][attestationHash];
    }
}
