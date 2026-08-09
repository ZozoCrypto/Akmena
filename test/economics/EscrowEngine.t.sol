// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {EscrowEngine} from "../../src/economics/EscrowEngine.sol";
import {IEscrowEngine} from "../../src/economics/IEscrowEngine.sol";
import {LibStorage} from "../../src/storage/LibStorage.sol";

contract EscrowEngineTest is Test {
    EscrowEngine public engine;
    address public buyer = address(0x111);
    address public seller = address(0x222);

    function setUp() public {
        engine = new EscrowEngine();
    }

    function test_CreateEscrow() public {
        uint256 escrowId = engine.createEscrow(buyer, seller, 500);
        
        LibStorage.EscrowData memory data = engine.getEscrow(escrowId);
        assertEq(data.buyer, buyer);
        assertEq(data.seller, seller);
        assertEq(data.amount, 500);
        assertEq(data.status, 1); // 1 = Funded
    }

    function test_ReleaseEscrow() public {
        uint256 escrowId = engine.createEscrow(buyer, seller, 500);

        vm.expectEmit(true, true, true, true);
        emit IEscrowEngine.EscrowReleased(escrowId);

        vm.prank(buyer);
        engine.releaseEscrow(escrowId);
        
        LibStorage.EscrowData memory data = engine.getEscrow(escrowId);
        assertEq(data.status, 2); // 2 = Released
    }

    function test_RefundEscrow() public {
        uint256 escrowId = engine.createEscrow(buyer, seller, 500);

        vm.expectEmit(true, true, true, true);
        emit IEscrowEngine.EscrowRefunded(escrowId);

        vm.prank(seller);
        engine.refundEscrow(escrowId);
        
        LibStorage.EscrowData memory data = engine.getEscrow(escrowId);
        assertEq(data.status, 3); // 3 = Refunded
    }

    function test_RevertWhen_EscrowNotFound() public {
        vm.expectRevert(IEscrowEngine.EscrowNotFound.selector);
        engine.releaseEscrow(999);
    }

    function test_RevertWhen_ReleaseByWrongCaller() public {
        uint256 escrowId = engine.createEscrow(buyer, seller, 500);

        vm.prank(seller); // Seller cannot release, only buyer can
        vm.expectRevert(); 
        engine.releaseEscrow(escrowId);
    }
}
