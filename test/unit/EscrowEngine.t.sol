// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {EscrowEngine} from "../../src/economics/EscrowEngine.sol";
import {IEscrowEngine} from "../../src/economics/IEscrowEngine.sol";
import {LibStorage} from "../../src/storage/LibStorage.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @notice Minimal ERC20 for escrow testing.
contract MockAsset is ERC20 {
    constructor() ERC20("MockAsset", "MCK") {}
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @notice Gap-fill unit tests for the ERC20-based EscrowEngine.
/// @dev Covers the properties from test/unit/EscrowEngine.t.sol.bak (create,
///      duplicate prevention, unknown revert, storage, release, double-release,
///      exists-false, validation) against the current API:
///      createEscrow(address, address, uint256) etc. The .bak tested a removed
///      native-ETH API; these test the same properties on the new API.
contract EscrowEngineGapTest is Test {
    EscrowEngine public escrow;
    MockAsset public asset;

    address public buyer = address(0x100);
    address public seller = address(0x200);
    uint256 public amount = 1 ether;

    function setUp() public {
        asset = new MockAsset();
        escrow = new EscrowEngine(address(asset));

        asset.mint(buyer, 10 ether);
        vm.prank(buyer);
        asset.approve(address(escrow), 10 ether);
    }

    function test_CreateEscrow() public {
        vm.prank(buyer);
        uint256 id = escrow.createEscrow(buyer, seller, amount);

        // Exists = getEscrow does not revert and returns the buyer.
        LibStorage.EscrowData memory e = escrow.getEscrow(id);
        assertEq(e.buyer, buyer);
    }

    function test_CannotCreateDuplicateReference() public {
        bytes32 ref = keccak256("ref-1");

        vm.prank(buyer);
        escrow.createEscrow(buyer, seller, amount, ref);

        vm.expectRevert(IEscrowEngine.EscrowReferenceAlreadyUsed.selector);
        vm.prank(buyer);
        escrow.createEscrow(buyer, seller, amount, ref);
    }

    function test_GetUnknownEscrowReverts() public {
        // Covers the "exists returns false for unknown" property:
        // unknown IDs revert on access.
        vm.expectRevert(IEscrowEngine.EscrowNotFound.selector);
        escrow.getEscrow(999999);
    }

    function test_EscrowStoredCorrectly() public {
        vm.prank(buyer);
        uint256 id = escrow.createEscrow(buyer, seller, amount);

        LibStorage.EscrowData memory e = escrow.getEscrow(id);

        assertEq(e.buyer, buyer);
        assertEq(e.seller, seller);
        assertEq(e.amount, amount);
        assertEq(e.asset, address(asset));
        assertEq(e.status, 1); // Active
    }

    function test_ReleaseEscrow() public {
        vm.prank(buyer);
        uint256 id = escrow.createEscrow(buyer, seller, amount);

        uint256 before = asset.balanceOf(seller);

        vm.prank(buyer);
        escrow.releaseEscrow(id);

        LibStorage.EscrowData memory e = escrow.getEscrow(id);
        assertEq(e.status, 2); // Released
        assertEq(asset.balanceOf(seller), before + amount);
    }

    function test_CannotReleaseTwice() public {
        vm.prank(buyer);
        uint256 id = escrow.createEscrow(buyer, seller, amount);

        vm.prank(buyer);
        escrow.releaseEscrow(id);

        vm.expectRevert(IEscrowEngine.EscrowNotActive.selector);
        vm.prank(buyer);
        escrow.releaseEscrow(id);
    }

    function test_CannotUseZeroBuyer() public {
        vm.expectRevert(IEscrowEngine.InvalidAddress.selector);
        vm.prank(buyer);
        escrow.createEscrow(address(0), seller, amount);
    }

    function test_CannotUseZeroAmount() public {
        vm.expectRevert(IEscrowEngine.InvalidAmount.selector);
        vm.prank(buyer);
        escrow.createEscrow(buyer, seller, 0);
    }
}
