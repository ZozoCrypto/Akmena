// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {AkmenaToken} from "../../src/token/core/AkmenaToken.sol";
import {EscrowEngine} from "../../src/economics/EscrowEngine.sol";
import {IEscrowEngine} from "../../src/economics/IEscrowEngine.sol";
import {LibStorage} from "../../src/storage/LibStorage.sol";

contract EscrowEngineTest is Test {
    AkmenaToken public token;
    EscrowEngine public escrow;

    address public buyer = address(0x111);
    address public seller = address(0x222);
    address public attacker = address(0x333);

    uint256 internal constant FUNDING = 100 ether;

    function setUp() public {
        token = new AkmenaToken(buyer);
        escrow = new EscrowEngine(address(token));
    }

    function _createFundedEscrow() internal returns (uint256 id) {
        vm.prank(buyer);
        token.approve(address(escrow), FUNDING);

        vm.prank(buyer);
        id = escrow.createEscrow(buyer, seller, FUNDING);
    }

    function test_CreateEscrow_TransfersActualAKMIntoCustody() public {
        uint256 buyerBefore = token.balanceOf(buyer);
        uint256 escrowBefore = token.balanceOf(address(escrow));

        uint256 id = _createFundedEscrow();

        LibStorage.EscrowData memory data = escrow.getEscrow(id);

        assertEq(data.buyer, buyer);
        assertEq(data.seller, seller);
        assertEq(data.amount, FUNDING);
        assertEq(data.asset, address(token));
        assertEq(data.status, 1);

        assertEq(token.balanceOf(buyer), buyerBefore - FUNDING);

        assertEq(token.balanceOf(address(escrow)), escrowBefore + FUNDING);

        assertEq(escrow.totalLocked(), FUNDING);
    }

    function test_CreateEscrow_WithoutApprovalReverts() public {
        vm.prank(buyer);

        vm.expectRevert();

        escrow.createEscrow(buyer, seller, FUNDING);
    }

    function test_CreateEscrow_InsufficientBalanceReverts() public {
        address poorBuyer = address(0x444);

        vm.prank(poorBuyer);
        token.approve(address(escrow), 1 ether);

        vm.prank(poorBuyer);
        vm.expectRevert();

        escrow.createEscrow(poorBuyer, seller, 1 ether);
    }

    function test_ReleaseEscrowTransfersToSeller() public {
        uint256 id = _createFundedEscrow();

        uint256 sellerBefore = token.balanceOf(seller);
        uint256 escrowBefore = token.balanceOf(address(escrow));

        vm.prank(buyer);
        escrow.releaseEscrow(id);

        assertEq(token.balanceOf(seller), sellerBefore + FUNDING);

        assertEq(token.balanceOf(address(escrow)), escrowBefore - FUNDING);

        assertEq(escrow.totalLocked(), 0);

        LibStorage.EscrowData memory data = escrow.getEscrow(id);

        assertEq(data.status, 2);
    }

    function test_RefundEscrowTransfersToBuyer() public {
        uint256 id = _createFundedEscrow();

        uint256 buyerBefore = token.balanceOf(buyer);

        uint256 escrowBefore = token.balanceOf(address(escrow));

        vm.prank(seller);
        escrow.refundEscrow(id);

        assertEq(token.balanceOf(buyer), buyerBefore + FUNDING);

        assertEq(token.balanceOf(address(escrow)), escrowBefore - FUNDING);

        assertEq(escrow.totalLocked(), 0);

        LibStorage.EscrowData memory data = escrow.getEscrow(id);

        assertEq(data.status, 3);
    }

    function test_RevertWhen_EscrowNotFound() public {
        vm.expectRevert(IEscrowEngine.EscrowNotFound.selector);

        escrow.getEscrow(999);
    }

    function test_RevertWhen_ReleaseByWrongCaller() public {
        uint256 id = _createFundedEscrow();

        vm.prank(seller);

        vm.expectRevert(IEscrowEngine.UnauthorizedAccess.selector);

        escrow.releaseEscrow(id);
    }

    function test_RevertWhen_RefundByWrongCaller() public {
        uint256 id = _createFundedEscrow();

        vm.prank(buyer);

        vm.expectRevert(IEscrowEngine.UnauthorizedAccess.selector);

        escrow.refundEscrow(id);
    }

    function test_RevertWhen_ZeroAmount() public {
        vm.prank(buyer);

        vm.expectRevert(IEscrowEngine.InvalidAmount.selector);

        escrow.createEscrow(buyer, seller, 0);
    }

    function test_RevertWhen_DoubleRelease() public {
        uint256 id = _createFundedEscrow();

        vm.prank(buyer);
        escrow.releaseEscrow(id);

        vm.prank(buyer);
        vm.expectRevert(IEscrowEngine.EscrowNotActive.selector);

        escrow.releaseEscrow(id);
    }

    function test_RevertWhen_ReleaseAfterRefund() public {
        uint256 id = _createFundedEscrow();

        vm.prank(seller);
        escrow.refundEscrow(id);

        vm.prank(buyer);
        vm.expectRevert(IEscrowEngine.EscrowNotActive.selector);

        escrow.releaseEscrow(id);
    }

    function test_RevertWhen_RefundAfterRelease() public {
        uint256 id = _createFundedEscrow();

        vm.prank(buyer);
        escrow.releaseEscrow(id);

        vm.prank(seller);
        vm.expectRevert(IEscrowEngine.EscrowNotActive.selector);

        escrow.refundEscrow(id);
    }

    /// @notice R10 mutant-7 regression: createEscrow must revert when
    /// msg.sender != buyer. Without this check, anyone could create escrow
    /// records pulling funds from a buyer's wallet (via their standing
    /// approval) without the buyer's consent for that specific escrow.
    function test_R10_RevertWhen_CreateEscrowByNonBuyer() public {
        // Buyer approves the escrow (standing approval, as in normal use).
        vm.prank(buyer);
        token.approve(address(escrow), FUNDING);

        // Attacker tries to create an escrow naming the buyer.
        vm.prank(attacker);
        vm.expectRevert(IEscrowEngine.UnauthorizedAccess.selector);
        escrow.createEscrow(buyer, seller, FUNDING);

        // No escrow was created, no funds moved.
        assertEq(token.balanceOf(address(escrow)), 0);
    }

    /// @notice R10 mutant-1 regression: deploying with zero asset must revert.
    function test_R10_RevertWhen_DeployWithZeroAsset() public {
        vm.expectRevert(IEscrowEngine.InvalidAddress.selector);
        new EscrowEngine(address(0));
    }

    /// @notice R10 mutant-16 regression: releasing a non-existent escrow
    /// must revert EscrowNotFound (existing test only covers getEscrow).
    function test_R10_RevertWhen_ReleaseNonexistentEscrow() public {
        vm.prank(buyer);
        vm.expectRevert(IEscrowEngine.EscrowNotFound.selector);
        escrow.releaseEscrow(999);
    }

    /// @notice R10 mutant-17 regression: release must revert when escrow
    /// token balance is below the locked amount (defense-in-depth).
    function test_R10_RevertWhen_ReleaseInsufficientBalance() public {
        uint256 id = _createFundedEscrow();

        // Simulate unexpected balance deficit (e.g. fee-on-transfer edge).
        vm.prank(address(escrow));
        token.transfer(address(0x999), 1);

        vm.prank(buyer);
        vm.expectRevert(IEscrowEngine.InsufficientEscrowBalance.selector);
        escrow.releaseEscrow(id);
    }

    /// @notice R10 mutant-26 regression: refund must revert on insufficient
    /// balance (defense-in-depth, refund path).
    function test_R10_RevertWhen_RefundInsufficientBalance() public {
        uint256 id = _createFundedEscrow();

        vm.prank(address(escrow));
        token.transfer(address(0x999), 1);

        vm.prank(seller);
        vm.expectRevert(IEscrowEngine.InsufficientEscrowBalance.selector);
        escrow.refundEscrow(id);
    }

    /// @notice R10 mutant-27 regression: the balance check must not be
    /// inverted. With excess balance (donation), refund must still succeed.
    /// Mutant 27 (`amount < balance`) would wrongly revert here.
    function test_R10_RefundExcessBalanceSucceeds() public {
        uint256 id = _createFundedEscrow();

        // Donate 1 wei to the escrow: balance > amount.
        vm.prank(buyer);
        token.transfer(address(escrow), 1);

        uint256 buyerBefore = token.balanceOf(buyer);

        vm.prank(seller);
        escrow.refundEscrow(id);

        // Refund succeeds and returns exactly the locked amount.
        assertEq(token.balanceOf(buyer), buyerBefore + FUNDING);
    }

    /// @notice R10 mutant-28 regression: refund must decrement
    /// totalLockedByAsset by the full amount, not 1 wei.
    function test_R10_RefundAccountingExact() public {
        uint256 id = _createFundedEscrow();
        assertEq(escrow.totalLockedByAsset(address(token)), FUNDING);

        vm.prank(seller);
        escrow.refundEscrow(id);

        assertEq(escrow.totalLockedByAsset(address(token)), 0, "accounting must clear fully");
    }
}
