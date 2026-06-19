// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title Akmena Protocol Shared Types
/// @notice Shared enums used throughout the protocol.
library Types {
    enum AgreementStatus {
        Draft,
        Open,
        Funded,
        Accepted,
        Executing,
        Submitted,
        Validated,
        Settled,
        Closed,
        Cancelled,
        Expired
    }

    enum SettlementAsset {
        ETH,
        USDC,
        AKM,
        ERC20
    }

    enum VerificationLevel {
        None,
        Basic,
        Verified,
        Trusted
    }
}
