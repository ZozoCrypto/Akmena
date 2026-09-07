// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {DelegationEngine} from "../../src/authorization/DelegationEngine.sol";

contract DelegationEIP712DomainTest is Test {
    DelegationEngine internal delegation;

    function setUp() public {
        delegation = new DelegationEngine();
    }

    function test_EIP712DomainIsCanonical()
        public
        view
    {
        (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        ) = delegation.eip712Domain();

        assertEq(fields, bytes1(0x0f));
        assertEq(name, "AkmenaDelegationEngine");
        assertEq(version, "1");
        assertEq(chainId, block.chainid);
        assertEq(
            verifyingContract,
            address(delegation)
        );
        assertEq(salt, bytes32(0));
        assertEq(extensions.length, 0);
    }
}
