// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IEconomicCommitmentEngine} from "../economics/IEconomicCommitmentEngine.sol";

library LibEconomicCommitmentStorage {
    bytes32 internal constant ECONOMIC_STORAGE_POSITION =
        keccak256(abi.encode(uint256(keccak256("akmena.storage.economic.commitment")) - 1)) & ~bytes32(uint256(31));

    struct CommitmentData {
        bytes32 commitmentId;
        bytes32 agreementId;
        uint256 escrowId;
        address payer;
        address payee;
        address asset;
        uint256 amount;
        bytes32 termsHash;
        IEconomicCommitmentEngine.CommitmentStatus status;
    }

    struct SettlementData {
        bytes32 settlementId;
        bytes32 commitmentId;
        bytes32 agreementId;
        uint256 escrowId;
        address payer;
        address payee;
        address asset;
        uint256 amount;
        uint256 timestamp;
    }

    struct EconomicStorage {
        mapping(bytes32 => CommitmentData) commitments;
        mapping(bytes32 => bytes32) commitmentByAgreement;
        mapping(bytes32 => SettlementData) settlements;
    }

    function economic() internal pure returns (EconomicStorage storage es) {
        bytes32 position = ECONOMIC_STORAGE_POSITION;

        assembly {
            es.slot := position
        }
    }
}
