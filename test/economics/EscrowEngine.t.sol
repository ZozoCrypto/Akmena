// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {EscrowEngine} from "../../src/economics/EscrowEngine.sol";
import {IEscrowEngine} from "../../src/economics/IEscrowEngine.sol";
import {LibStorage} from "../../src/storage/LibStorage.sol";

contract EscrowEngineTest is Test {
    EscrowEngine public escrow;
    address public buyer = address(0x111);
    address public seller = address(0x222);

    function setUp() public {
        escrow = new EscrowEngine();
    }

    function test_CreateEscrow() public {
        vm.prank(buyer);
        uint256 id = escrow.createEscrow(buyer, seller, 100 ether);
        assertEq(id, 1);

        LibStorage.EscrowData memory data = escrow.getEscrow(1);
        assertEq(data.buyer, buyer);
        assertEq(data.seller, seller);
        assertEq(data.amount, 100 ether);
        assertEq(data.status, 1);
    }

    function test_ReleaseEscrow() public {
        vm.prank(buyer);
        escrow.createEscrow(buyer, seller, 100 ether);

        vm.prank(buyer);
        escrow.releaseEscrow(1);

        LibStorage.EscrowData memory data = escrow.getEscrow(1);
        assertEq(data.status, 2);
    }

    function test_RefundEscrow() public {
        vm.prank(buyer);
        escrow.createEscrow(buyer, seller, 100 ether);

        vm.prank(seller);
        escrow.refundEscrow(1);

        LibStorage.EscrowData memory data = escrow.getEscrow(1);
        assertEq(data.status, 3);
    }

    function test_RevertWhen_EscrowNotFound() public {
        vm.expectRevert(IEscrowEngine.EscrowNotFound.selector);
        escrow.getEscrow(999);
    }

    function test_RevertWhen_ReleaseByWrongCaller() public {
        vm.prank(buyer);
        escrow.createEscrow(buyer, seller, 100 ether);

        vm.prank(seller);
        vm.expectRevert(IEscrowEngine.UnauthorizedAccess.selector);
        escrow.releaseEscrow(1);
    }

    function test_RevertWhen_WrongSenderCreates() public {
        vm.prank(buyer);
        vm.expectRevert(IEscrowEngine.InvalidAmount.selector);
        escrow.createEscrow(buyer, seller, 0);
    }
}
