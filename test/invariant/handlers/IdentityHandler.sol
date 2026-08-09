// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../../../src/identity/Identity.sol";

contract IdentityHandler {
    Identity public identity;

    constructor(Identity _identity) {
        identity = _identity;
    }

    function updateMetadata(string calldata uri) public {
        try identity.updateMetadata(uri) {} catch {}
    }

    function transferOwnership(address newOwner) public {
        if (newOwner == address(0)) return;
        try identity.transferOwnership(newOwner) {} catch {}
    }

    function deactivate() public {
        try identity.deactivate() {} catch {}
    }
}
