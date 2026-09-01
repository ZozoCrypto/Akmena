// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";

import {AkmenaToken} from "../../src/token/core/AkmenaToken.sol";

contract TokenEconomicInvariant is StdInvariant, Test {
    uint256 internal constant MAX_SUPPLY =
        1_000_000_000 ether;

    address internal constant INITIAL_HOLDER =
        address(0x1000);

    address internal constant HOLDER_A =
        address(0xA001);

    address internal constant HOLDER_B =
        address(0xB001);

    bytes4 internal constant TRANSFER_SELECTOR =
        bytes4(keccak256("transfer(address,uint256)"));

    bytes4 internal constant TRANSFER_FROM_SELECTOR =
        bytes4(keccak256("transferFrom(address,address,uint256)"));

    AkmenaToken internal token;

    function setUp() public {
        token = new AkmenaToken(INITIAL_HOLDER);

        // Establish real balances for the controlled holders.
        vm.prank(INITIAL_HOLDER);
        token.transfer(HOLDER_A, 1_000_000 ether);

        vm.prank(INITIAL_HOLDER);
        token.transfer(HOLDER_B, 1_000_000 ether);

        targetContract(address(token));

        targetSelector(
            FuzzSelector({
                addr: address(token),
                selectors: _selectors()
            })
        );
    }

    function _selectors()
        internal
        pure
        returns (bytes4[] memory selectors)
    {
        selectors = new bytes4[](2);

        selectors[0] = TRANSFER_SELECTOR;
        selectors[1] = TRANSFER_FROM_SELECTOR;
    }

    function invariant_TotalSupplyRemainsFixed()
        public
        view
    {
        assertEq(
            token.totalSupply(),
            MAX_SUPPLY
        );
    }

    function invariant_MaxSupplyIsNeverExceeded()
        public
        view
    {
        assertLe(
            token.totalSupply(),
            token.MAX_SUPPLY()
        );
    }

    function invariant_HolderBalancesCannotExceedSupply()
        public
        view
    {
        assertLe(
            token.balanceOf(INITIAL_HOLDER),
            token.totalSupply()
        );

        assertLe(
            token.balanceOf(HOLDER_A),
            token.totalSupply()
        );

        assertLe(
            token.balanceOf(HOLDER_B),
            token.totalSupply()
        );
    }

    function invariant_TokenMetadataIsStable()
        public
        view
    {
        assertEq(token.decimals(), 18);
        assertEq(token.symbol(), "AKM");
        assertEq(token.name(), "Akmena Token");
    }
}
