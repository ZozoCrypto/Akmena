// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaCore} from "../../src/core/AkmenaCore.sol";
import {AkmenaPolicyBoundary} from "../../src/authorization/AkmenaPolicyBoundary.sol";

contract LegacyExecutionRetirementTest is Test {
    AkmenaPolicyBoundary internal boundary;

    function setUp() public {
        AkmenaCore core = new AkmenaCore();
        boundary = new AkmenaPolicyBoundary(address(core));
    }

    function test_LegacyExecutionPathIsPermanentlyDisabled() public {
        vm.expectRevert(
            AkmenaPolicyBoundary.LegacyExecutionDisabled.selector
        );

        boundary.executeAgentCall(
            address(0x1111),
            address(0x2222),
            1 ether,
            bytes32(0),
            1,
            hex""
        );
    }
}
