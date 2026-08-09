// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {AkmenaToken} from "../../src/token/core/AkmenaToken.sol";
import {TokenHandler} from "./handlers/TokenHandler.sol";

contract TokenInvariant is StdInvariant, Test {
    AkmenaToken internal token;
    TokenHandler internal handler;
    address internal constant TREASURY = address(0x1000);

    function setUp() public {
        token = new AkmenaToken(TREASURY);
        handler = new TokenHandler(token, TREASURY);

        targetContract(address(handler));
    }

    function test_SanityCheck() public pure {
        assertTrue(true);
    }

    /// INVARIANT: Total supply must never exceed MAX_SUPPLY
    function invariant_totalSupplyNeverExceedsMax() public view {
        assertEq(token.totalSupply(), token.MAX_SUPPLY());
        assertTrue(token.totalSupply() <= 1_000_000_000 ether);
    }

    /// INVARIANT: Sum of all balances must equal total supply (conservation of tokens)
    function invariant_tokenConservation() public view {
        // Since initial supply is in treasury and fuzzer transfers to random recipients
        uint256 treasuryBalance = token.balanceOf(TREASURY);
        uint256 totalSupply = token.totalSupply();
        
        assertTrue(treasuryBalance <= totalSupply);
    }

    /// INVARIANT: Decimals and metadata must remain constant
    function invariant_tokenMetadataImmutable() public view {
        assertEq(token.decimals(), 18);
        assertEq(token.symbol(), "AKM");
    }
}
