// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {
    AkmenaPolicyBoundary
} from "../../src/authorization/AkmenaPolicyBoundary.sol";

contract AttackLegacyExecutionRetirementCanonicalTest is Test {
    AkmenaPolicyBoundary internal boundary;

    address internal attacker = address(0xBEEF);
    address internal target = address(0xCAFE);

    function setUp() public {
        boundary = new AkmenaPolicyBoundary(address(0));
    }

    function test_LegacyExecutionEntrypointIsPermanentlyDisabled()
        public
    {
        vm.prank(attacker);

        vm.expectRevert();

        boundary.executeAgentCall(
            attacker,
            target,
            0,
            bytes32(0),
            0,
            ""
        );
    }

    function test_LegacyExecutionCannotBeUsedWithArbitraryCalldata()
        public
    {
        bytes memory maliciousPayload =
            abi.encodeWithSignature(
                "drain(address,uint256)",
                attacker,
                type(uint256).max
            );

        vm.prank(attacker);

        vm.expectRevert();

        boundary.executeAgentCall(
            attacker,
            target,
            type(uint256).max,
            bytes32(0),
            0,
            maliciousPayload
        );
    }

    function test_LegacyExecutionCannotBecomeCanonicalViaZeroProof()
        public
    {
        bytes memory payload =
            abi.encodeWithSignature(
                "execute()"
            );

        vm.prank(attacker);

        vm.expectRevert();

        boundary.executeAgentCall(
            attacker,
            target,
            0,
            bytes32(0),
            0,
            payload
        );
    }
}
