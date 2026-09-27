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
}
