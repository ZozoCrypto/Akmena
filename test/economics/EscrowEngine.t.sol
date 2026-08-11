// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {EscrowEngine} from "../../src/economics/EscrowEngine.sol";
import {LibStorage} from "../../src/storage/LibStorage.sol";

contract EscrowEngineTest is Test {
    EscrowEngine public engine;
    address public buyer = address(0x111);
    address public seller = address(0x222);
    address public attacker = address(0x333);
    uint256 public amount = 1000 ether;

    function setUp() public {
        engine = new EscrowEngine();
    }

    function test_CreateEscrow() public {
        vm.prank(buyer);
        uint256 id = engine.createEscrow(buyer, seller, amount);
        assertEq(id, 1);
        
        LibStorage.EscrowData memory data = engine.getEscrow(id);
        assertEq(data.buyer, buyer);
        assertEq(data.seller, seller);
        assertEq(data.amount, amount);
        assertEq(data.status, 1); // Funded
    }

    function test_RevertWhen_WrongSenderCreates() public {
        vm.prank(attacker);
        vm.expectRevert(bytes4(keccak256("UnauthorizedAccess()")));
        engine.createEscrow(buyer, seller, amount);
    }

    function test_ReleaseEscrow() public {
        vm.prank(buyer);
        uint256 id = engine.createEscrow(buyer, seller, amount);

        vm.prank(buyer);
        engine.releaseEscrow(id);

        LibStorage.EscrowData memory data = engine.getEscrow(id);
        assertEq(data.status, 2); // Released
    }

    function test_RevertWhen_ReleaseByWrongCaller() public {
        vm.prank(buyer);
        uint256 id = engine.createEscrow(buyer, seller, amount);

        vm.prank(attacker);
        vm.expectRevert(bytes4(keccak256("UnauthorizedAccess()")));
        engine.releaseEscrow(id);
    }

    function test_RefundEscrow() public {
        vm.prank(buyer);
        uint256 id = engine.createEscrow(buyer, seller, amount);

        // Refund requires seller authorization
        vm.prank(seller);
        engine.refundEscrow(id);

        LibStorage.EscrowData memory data = engine.getEscrow(id);
        assertEq(data.status, 3); // Refunded
    }
    
    function test_RevertWhen_EscrowNotFound() public {
        vm.expectRevert(bytes4(keccak256("EscrowNotFound()")));
        engine.getEscrow(999);
    }
}
