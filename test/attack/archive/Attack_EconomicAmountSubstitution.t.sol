// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaCore} from "../../../src/core/AkmenaCore.sol";
import {AkmenaPolicyBoundary} from "../../../src/authorization/AkmenaPolicyBoundary.sol";

contract EconomicSubstitutionTarget {

    uint256 public executedAmount;

    function execute(
        uint256 amount
    )
        external
    {
        executedAmount += amount;
    }
}

contract Attack_EconomicAmountSubstitutionTest is Test {

    AkmenaCore internal core;
    AkmenaPolicyBoundary internal boundary;
    EconomicSubstitutionTarget internal target;

    address internal operator =
        address(0x1111);

    address internal agent =
        address(0x2222);

    function setUp()
        public
    {
        core =
            new AkmenaCore();

        boundary =
            new AkmenaPolicyBoundary(
                address(core)
            );

        target =
            new EconomicSubstitutionTarget();

        vm.prank(operator);

        boundary.setAgentPolicy(
            agent,
            1 ether,
            1 ether,
            false
        );
    }

    function test_Attack_DeclaredAmountDoesNotBindCalldataAmount()
        public
    {
        bytes memory payload =
            abi.encodeWithSelector(
                EconomicSubstitutionTarget.execute.selector,
                100 ether
            );

        vm.prank(agent);

        boundary.executeAgentCall(
            operator,
            address(target),
            1 ether,
            bytes32(0),
            0,
            payload
        );

        assertEq(
            target.executedAmount(),
            100 ether,
            "expected current boundary to execute calldata amount"
        );
    }
}
