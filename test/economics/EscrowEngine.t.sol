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
        vm.expectEmit(true, true, true, true);
        emit IEscrowEngine.EscrowCreated(1, buyer, seller, 500);

        uint256 id = engine.createEscrow(buyer, seller, 500);
        assertEq(id, 1, "First ID should be 1");
        
        LibStorage.EscrowData memory data = engine.getEscrow(id);
        assertEq(data.buyer, buyer);
        assertEq(data.seller, seller);
        assertEq(data.amount, 500);
        assertEq(data.status, 1); // Funded
    }

    function test_ReleaseEscrow() public {
        uint256 id = engine.createEscrow(buyer, seller, 500);

        vm.expectEmit(true, true, true, true);
        emit IEscrowEngine.EscrowReleased(id);

        engine.releaseEscrow(id);
        
        LibStorage.EscrowData memory data = engine.getEscrow(id);
        assertEq(data.status, 2, "Status should be Released");
    }

    function test_RefundEscrow() public {
        uint256 id = engine.createEscrow(buyer, seller, 500);

        vm.expectEmit(true, true, true, true);
        emit IEscrowEngine.EscrowRefunded(id);

        engine.refundEscrow(id); // Only seller can authorize refund
        
        LibStorage.EscrowData memory data = engine.getEscrow(id);
        assertEq(data.status, 3, "Status should be Refunded");
    }

    function test_RevertWhen_ReleaseByWrongCaller() public {
        uint256 id = engine.createEscrow(buyer, seller, 500);

        vm.expectRevert(IEscrowEngine.UnauthorizedAccess.selector);
        engine.releaseEscrow(id); // Seller cannot release to themselves
    }
}
