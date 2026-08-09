// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/economics/EscrowEngine.sol";

contract EscrowHandler is Test {
    EscrowEngine public escrow;
    
    uint256 public expectedActiveVolume;
    mapping(uint256 => bool) public isActive;
    mapping(uint256 => uint256) public escrowAmounts;
    uint256[] public activeEscrows;

    constructor(EscrowEngine _escrow) {
        escrow = _escrow;
    }

    function activeEscrowsLength() public view returns (uint256) {
        return activeEscrows.length;
    }

    function createEscrow(address buyer, address seller, uint256 amount) public {
        amount = bound(amount, 1, type(uint96).max);
        if (buyer == address(0)) buyer = address(0x1);
        if (seller == address(0)) seller = address(0x2);

        uint256 id = escrow.createEscrow(buyer, seller, amount);
        
        expectedActiveVolume += amount;
        isActive[id] = true;
        escrowAmounts[id] = amount;
        activeEscrows.push(id);
    }

    function releaseEscrow(uint256 seed) public {
        if (activeEscrows.length == 0) return;
        uint256 index = seed % activeEscrows.length;
        uint256 id = activeEscrows[index];

        if (isActive[id]) {
            address buyer = escrow.getEscrow(id).buyer;
            vm.prank(buyer);
            escrow.releaseEscrow(id);
            
            expectedActiveVolume -= escrowAmounts[id];
            isActive[id] = false;
        }
    }
    
    function refundEscrow(uint256 seed) public {
        if (activeEscrows.length == 0) return;
        uint256 index = seed % activeEscrows.length;
        uint256 id = activeEscrows[index];

        if (isActive[id]) {
            address seller = escrow.getEscrow(id).seller;
            vm.prank(seller);
            escrow.refundEscrow(id);
            
            expectedActiveVolume -= escrowAmounts[id];
            isActive[id] = false;
        }
    }
}

contract AkmenaStatefulInvariantTest is Test {
    EscrowEngine public escrow;
    EscrowHandler public handler;

    function setUp() public {
        escrow = new EscrowEngine();
        handler = new EscrowHandler(escrow);
        targetContract(address(handler));
    }

    function test_SanityCheck() public pure {
        assertTrue(true);
    }

    function invariant_ActiveVolumeMatchesState() public view {
        uint256 actualVolume = 0;
        
        for(uint i = 0; i < handler.activeEscrowsLength(); i++) {
            uint256 id = handler.activeEscrows(i);
            
            if (handler.isActive(id)) {
                assertEq(escrow.getEscrow(id).status, 1);
                actualVolume += escrow.getEscrow(id).amount;
            } else {
                uint256 status = escrow.getEscrow(id).status;
                assertTrue(status == 2 || status == 3);
            }
        }
        
        assertEq(actualVolume, handler.expectedActiveVolume());
    }
}
