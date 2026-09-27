// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";

import {AkmenaToken} from "../src/token/core/AkmenaToken.sol";
import {EscrowEngine} from "../src/economics/EscrowEngine.sol";
import {LibStorage} from "../src/storage/LibStorage.sol";

contract EscrowHandler is Test {
    EscrowEngine public escrow;
    AkmenaToken public token;

    uint256 public expectedActiveVolume;

    mapping(uint256 => bool) public isActive;
    mapping(uint256 => uint256) public escrowAmounts;

    uint256[] public activeEscrows;

    address public immutable buyer;

    constructor(EscrowEngine _escrow, AkmenaToken _token) {
        escrow = _escrow;
        token = _token;
        buyer = address(this);

        // The handler is the canonical buyer for this invariant campaign.
        // It receives a large bounded AKM budget from the test setup.
        token.approve(address(escrow), type(uint256).max);
    }

    function activeEscrowsLength() public view returns (uint256) {
        return activeEscrows.length;
    }

    function createEscrow(address, address seller, uint256 amount) public {
        amount = bound(amount, 1, 100_000 ether);

        // Prevent collisions with zero-address validation while retaining
        // fuzz variation for beneficiaries.
        if (seller == address(0) || seller == buyer) {
            seller = address(0x2);
        }

        // Every successful escrow must be backed by real AKM.
        uint256 available = token.balanceOf(buyer);

        if (available < amount) {
            return;
        }

        uint256 id = escrow.createEscrow(buyer, seller, amount);

        expectedActiveVolume += amount;
        isActive[id] = true;
        escrowAmounts[id] = amount;
        activeEscrows.push(id);
    }

    function releaseEscrow(uint256 seed) public {
        if (activeEscrows.length == 0) {
            return;
        }

        uint256 index = seed % activeEscrows.length;
        uint256 id = activeEscrows[index];

        if (!isActive[id]) {
            return;
        }

        // Buyer authority is explicit and is the handler itself.
        escrow.releaseEscrow(id);

        expectedActiveVolume -= escrowAmounts[id];
        isActive[id] = false;
    }

    function refundEscrow(uint256 seed) public {
        if (activeEscrows.length == 0) {
            return;
        }

        uint256 index = seed % activeEscrows.length;
        uint256 id = activeEscrows[index];

        if (!isActive[id]) {
            return;
        }

        // Refund authority belongs to the escrow seller.
        address seller = escrow.getEscrow(id).seller;

        vm.prank(seller);
        escrow.refundEscrow(id);

        expectedActiveVolume -= escrowAmounts[id];
        isActive[id] = false;
    }
}

contract AkmenaStatefulInvariantTest is Test {
    AkmenaToken public token;
    EscrowEngine public escrow;
    EscrowHandler public handler;

    uint256 internal constant HANDLER_FUNDING = 10_000_000 ether;

    function setUp() public {
        // Test contract initially owns the fixed AKM supply.
        token = new AkmenaToken(address(this));

        escrow = new EscrowEngine(address(token));

        handler = new EscrowHandler(escrow, token);

        // Fund the handler with real AKM so invariant calls can actually
        // create funded escrows rather than silently reverting.
        require(token.transfer(address(handler), HANDLER_FUNDING));

        targetContract(address(handler));
    }

    function test_SanityCheck() public pure {
        assertTrue(true);
    }

    function invariant_ActiveVolumeMatchesState() public view {
        uint256 actualVolume = 0;

        for (uint256 i = 0; i < handler.activeEscrowsLength(); ++i) {
            uint256 id = handler.activeEscrows(i);

            LibStorage.EscrowData memory data = escrow.getEscrow(id);

            if (handler.isActive(id)) {
                assertEq(data.status, 1, "Active handler escrow is not ACTIVE");

                actualVolume += data.amount;
            } else {
                assertTrue(data.status == 2 || data.status == 3, "Inactive escrow is not terminal");
            }
        }

        assertEq(actualVolume, handler.expectedActiveVolume(), "Ghost active volume diverged from escrow state");

        assertEq(escrow.totalLocked(), actualVolume, "Escrow totalLocked diverged from active escrow volume");

        assertGe(
            token.balanceOf(address(escrow)), escrow.totalLocked(), "Escrow custody does not back locked liability"
        );
    }
}
