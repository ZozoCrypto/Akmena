// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AKMAuthorization} from "../../src/token/extensions/AKMAuthorization.sol";

contract MockAuthorization is AKMAuthorization {}

contract AKMAuthorizationTest is Test {
    MockAuthorization auth;

    function setUp() public {
        auth = new MockAuthorization();
    }

    function testAuthorizationStartsUnused() public view {
        assertFalse(auth.authorizationState(address(this), bytes32(uint256(1))));
    }
}
