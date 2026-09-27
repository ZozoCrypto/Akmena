// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {AkmenaToken} from "../../src/token/core/AkmenaToken.sol";
import {EscrowEngine} from "../../src/economics/EscrowEngine.sol";
import {IEscrowEngine} from "../../src/economics/IEscrowEngine.sol";
import {LibStorage} from "../../src/storage/LibStorage.sol";

contract MockStablecoin is ERC20 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract FeeOnTransferToken is ERC20 {
    constructor() ERC20("Fee Token", "FEE") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        bool success = super.transferFrom(from, to, value);
        uint256 fee = value / 100;
        if (fee > 0) {
            _burn(to, fee);
        }
        return success;
    }
}

contract EscrowEngineMultiAssetTest is Test {
    uint256 internal constant AMOUNT = 100 ether;

    address internal buyer = address(0x111);
    address internal seller = address(0x222);

    AkmenaToken internal akm;
    MockStablecoin internal usdc;
    MockStablecoin internal eurc;
    FeeOnTransferToken internal feeToken;
    EscrowEngine internal escrow;

    function setUp() public {
        akm = new AkmenaToken(buyer);
        usdc = new MockStablecoin("USD Coin", "USDC");
        eurc = new MockStablecoin("Euro Coin", "EURC");
        feeToken = new FeeOnTransferToken();

        usdc.mint(buyer, 1_000 ether);
        eurc.mint(buyer, 1_000 ether);
        feeToken.mint(buyer, 1_000 ether);

        escrow = new EscrowEngine(address(akm));
    }

    function test_CreateUSDC_EscrowUsesExplicitAssetAndIndependentAccounting() public {
        bytes32 referenceId = keccak256("usdc-escrow");

        vm.startPrank(buyer);
        usdc.approve(address(escrow), AMOUNT);
        uint256 escrowId = escrow.createEscrow(buyer, seller, address(usdc), AMOUNT, referenceId);
        vm.stopPrank();

        LibStorage.EscrowData memory data = escrow.getEscrow(escrowId);

        assertEq(data.asset, address(usdc));
        assertEq(data.amount, AMOUNT);
        assertEq(data.referenceId, referenceId);
        assertEq(data.status, 1);

        assertEq(usdc.balanceOf(address(escrow)), AMOUNT);
        assertEq(escrow.totalLockedByAsset(address(usdc)), AMOUNT);

        // Legacy AKM accounting remains isolated from USDC.
        assertEq(escrow.totalLocked(), 0);
    }

    function test_CreateEURC_EscrowAndReleaseUsesEURC_NotDefaultAKM() public {
        vm.startPrank(buyer);
        eurc.approve(address(escrow), AMOUNT);
        uint256 escrowId = escrow.createEscrow(buyer, seller, address(eurc), AMOUNT);
        vm.stopPrank();

        uint256 sellerEURCBefore = eurc.balanceOf(seller);
        uint256 sellerAKMBefore = akm.balanceOf(seller);

        vm.prank(buyer);
        escrow.releaseEscrow(escrowId);

        assertEq(eurc.balanceOf(seller), sellerEURCBefore + AMOUNT);
        assertEq(akm.balanceOf(seller), sellerAKMBefore);
        assertEq(escrow.totalLockedByAsset(address(eurc)), 0);
        assertEq(escrow.totalLocked(), 0);
    }

    function test_ExplicitAKM_EscrowPreservesLegacyTotalLocked() public {
        vm.startPrank(buyer);
        akm.approve(address(escrow), AMOUNT);
        uint256 escrowId = escrow.createEscrow(buyer, seller, address(akm), AMOUNT);
        vm.stopPrank();

        assertEq(escrow.totalLockedByAsset(address(akm)), AMOUNT);
        assertEq(escrow.totalLocked(), AMOUNT);

        vm.prank(buyer);
        escrow.releaseEscrow(escrowId);

        assertEq(escrow.totalLockedByAsset(address(akm)), 0);
        assertEq(escrow.totalLocked(), 0);
    }

    function test_USDCAndAKM_AccountingRemainIndependent() public {
        vm.startPrank(buyer);

        akm.approve(address(escrow), AMOUNT);
        uint256 akmEscrowId = escrow.createEscrow(buyer, seller, AMOUNT);

        usdc.approve(address(escrow), AMOUNT);
        uint256 usdcEscrowId = escrow.createEscrow(buyer, seller, address(usdc), AMOUNT);

        vm.stopPrank();

        assertEq(escrow.totalLocked(), AMOUNT);
        assertEq(escrow.totalLockedByAsset(address(akm)), AMOUNT);
        assertEq(escrow.totalLockedByAsset(address(usdc)), AMOUNT);

        vm.prank(buyer);
        escrow.releaseEscrow(usdcEscrowId);

        assertEq(escrow.totalLocked(), AMOUNT);
        assertEq(escrow.totalLockedByAsset(address(akm)), AMOUNT);
        assertEq(escrow.totalLockedByAsset(address(usdc)), 0);

        vm.prank(buyer);
        escrow.releaseEscrow(akmEscrowId);

        assertEq(escrow.totalLocked(), 0);
        assertEq(escrow.totalLockedByAsset(address(akm)), 0);
    }

    function test_FeeOnTransferTokenCannotCreateUnderfundedEscrow() public {
        vm.startPrank(buyer);
        feeToken.approve(address(escrow), AMOUNT);

        vm.expectRevert(IEscrowEngine.EscrowFundingMismatch.selector);
        escrow.createEscrow(buyer, seller, address(feeToken), AMOUNT);

        vm.stopPrank();

        assertEq(feeToken.balanceOf(address(escrow)), 0);
        assertEq(escrow.totalLockedByAsset(address(feeToken)), 0);
    }

    function test_RevertWhen_ExplicitAssetIsNotAContract() public {
        address notAContract = address(0xBEEF);

        vm.prank(buyer);
        vm.expectRevert(IEscrowEngine.InvalidAsset.selector);
        escrow.createEscrow(buyer, seller, notAContract, AMOUNT);
    }
}
