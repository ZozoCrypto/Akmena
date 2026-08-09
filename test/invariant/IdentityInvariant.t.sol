// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "forge-std/StdInvariant.sol";

import "../../src/identity/Identity.sol";
import "./handlers/IdentityHandler.sol";

contract IdentityInvariant is StdInvariant, Test {

    Identity identity;
    IdentityHandler handler;

    address constant OWNER = address(0xBEEF);

    function setUp() public {

        identity = new Identity();

        identity.initialize(
            1,
            OWNER,
            "ipfs://genesis"
        );

        handler = new IdentityHandler(identity);

        targetContract(address(handler));
    }

    ////////////////////////////////////////////////////////////
    // Identity ID is immutable
    ////////////////////////////////////////////////////////////

    function invariant_identityIdNeverChanges() public view {
        assertEq(identity.identityId(), 1);
    }

    ////////////////////////////////////////////////////////////
    // Protocol version never changes
    ////////////////////////////////////////////////////////////

    function invariant_protocolVersionConstant() public view {
        assertEq(identity.protocolVersion(), "2.0.0");
    }

    ////////////////////////////////////////////////////////////
    // Owner can never become zero
    ////////////////////////////////////////////////////////////

    function invariant_ownerNeverZero() public view {
        assertTrue(identity.owner() != address(0));
    }

    ////////////////////////////////////////////////////////////
    // Metadata always exists
    ////////////////////////////////////////////////////////////

    function invariant_metadataAlwaysValid() public view {
        bytes memory b = bytes(identity.metadataURI());
        assertTrue(b.length > 0);
    }
}
