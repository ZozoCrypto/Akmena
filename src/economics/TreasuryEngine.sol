// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ITreasuryEngine} from "./ITreasuryEngine.sol";

/// @title TreasuryEngine
/// @notice Canonical AKM treasury custody boundary.
///
/// Economic authority:
/// - AkmenaToken is the source of truth for supply and ownership.
/// - This contract's AKM balance is its actual treasury custody.
/// - Treasury accounting does not create or destroy value.
/// - Funding moves real AKM into this contract.
/// - Disbursement moves real AKM out of this contract.
/// - Treasury has no independent supply ledger.
contract TreasuryEngine is ITreasuryEngine {
    using SafeERC20 for IERC20;

    address public immutable override token;
    address public immutable override owner;

    IERC20 private immutable _asset;

    constructor(
        address token_,
        address owner_
    ) {
        if (token_ == address(0)) {
            revert InvalidToken();
        }

        if (owner_ == address(0)) {
            revert InvalidAddress();
        }

        token = token_;
        owner = owner_;
        _asset = IERC20(token_);
    }

    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert Unauthorized();
        }
        _;
    }

    /// @notice Deposit actual AKM into treasury custody.
    /// @dev Caller must approve this treasury for the amount.
    function fundTreasury(
        uint256 amount
    )
        external
        override
    {
        if (amount == 0) {
            revert InvalidAmount();
        }

        _asset.safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );

        emit TreasuryFunded(
            msg.sender,
            amount
        );
    }

    /// @notice Transfer actual AKM out of treasury custody.
    /// @dev Restricted to the treasury controller.
    function disburseFunds(
        address to,
        uint256 amount
    )
        external
        override
        onlyOwner
    {
        if (to == address(0)) {
            revert InvalidAddress();
        }

        if (amount == 0) {
            revert InvalidAmount();
        }

        uint256 balance =
            _asset.balanceOf(address(this));

        if (balance < amount) {
            revert InsufficientTreasuryFunds();
        }

        _asset.safeTransfer(to, amount);

        emit FundsDisbursed(
            to,
            amount
        );
    }

    /// @notice Returns authoritative token supply and actual treasury custody.
    function getTreasuryState()
        external
        view
        override
        returns (
            uint256 totalSupply,
            uint256 treasuryBalance
        )
    {
        totalSupply =
            _asset.totalSupply();

        treasuryBalance =
            _asset.balanceOf(address(this));
    }
}
