// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";

import {AkmenaToken} from "../../src/token/core/AkmenaToken.sol";

contract AkmenaTokenTest is Test {
    AkmenaToken internal token;

    address internal constant TREASURY = address(0x1000);

    uint256 internal constant SUPPLY = 1_000_000_000 ether;

    function setUp() public {
        token = new AkmenaToken(TREASURY);
    }

    function testName() public view {
        assertEq(token.name(), "Akmena Token");
    }

    function testSymbol() public view {
        assertEq(token.symbol(), "AKM");
    }

    function testDecimals() public view {
        assertEq(token.decimals(), 18);
    }

    function testTotalSupply() public view {
        assertEq(token.totalSupply(), SUPPLY);
    }

    function testTreasuryOwnsEntireSupply() public view {
        assertEq(token.balanceOf(TREASURY), SUPPLY);
    }

    function testMaxSupplyConstant() public view {
        assertEq(token.MAX_SUPPLY(), SUPPLY);
    }

    function testCannotDeployWithZeroAddress() public {
        vm.expectRevert(AkmenaToken.InvalidInitialHolder.selector);

        new AkmenaToken(address(0));
    }
}
