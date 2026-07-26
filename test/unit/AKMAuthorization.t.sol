// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AKMAuthorization} from "../../src/token/extensions/AKMAuthorization.sol";

contract MockAuthorization is AKMAuthorization {
    function transferWithAuthorization(
        address from,
        address to,
        uint256 value,
        uint256 validAfter,
        uint256 validBefore,
        bytes32 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override {}

    function receiveWithAuthorization(
        address from,
        address to,
        uint256 value,
        uint256 validAfter,
        uint256 validBefore,
        bytes32 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override {}

    function cancelAuthorization(
        address authorizer, 
        bytes32 nonce, 
        uint8 v, 
        bytes32 r, 
        bytes32 s
    ) external override {}
}

contract AKMAuthorizationTest is Test {
    MockAuthorization auth;

    function setUp() public {
        auth = new MockAuthorization();
    }

    function testAuthorizationStartsUnused() public view {
        assertFalse(auth.authorizationState(address(this), bytes32(uint256(1))));
    }
}
