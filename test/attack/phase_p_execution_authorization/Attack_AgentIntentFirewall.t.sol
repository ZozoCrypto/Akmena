// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";


contract AgentIntentFirewall {

    struct Policy {
        uint256 maxPerExecution;
        uint256 dailyLimit;
        uint256 spentToday;
    }


    mapping(address => Policy)
        public policies;


    error AmountExceeded();
    error DailyLimitExceeded();


    function setPolicy(
        address agent,
        uint256 maxExecution,
        uint256 daily
    )
        external
    {
        policies[agent] =
            Policy({
                maxPerExecution: maxExecution,
                dailyLimit: daily,
                spentToday: 0
            });
    }


    function authorize(
        address agent,
        uint256 amount
    )
        external
    {
        Policy storage p =
            policies[agent];


        if (
            amount > p.maxPerExecution
        ) {
            revert AmountExceeded();
        }


        if (
            p.spentToday + amount >
            p.dailyLimit
        ) {
            revert DailyLimitExceeded();
        }


        p.spentToday += amount;
    }
}



contract Attack_AgentIntentFirewallTest is Test {


    AgentIntentFirewall internal firewall;


    address internal agent =
        address(0xA11CE);


    function setUp()
        public
    {
        firewall =
            new AgentIntentFirewall();


        firewall.setPolicy(
            agent,
            10 ether,
            100 ether
        );
    }



    function test_AgentCannotExceedPerExecutionLimit()
        public
    {
        vm.expectRevert(
            AgentIntentFirewall.AmountExceeded.selector
        );


        firewall.authorize(
            agent,
            11 ether
        );
    }



    function test_AgentCanExecuteWithinLimit()
        public
    {
        firewall.authorize(
            agent,
            10 ether
        );


        (
            ,
            ,
            uint256 spentToday
        ) = firewall.policies(agent);

        assertEq(
            spentToday,
            10 ether
        );
    }




    function test_DailyLimitCannotBeBypassed()
        public
    {
        for (uint256 i = 0; i < 10; i++) {
            firewall.authorize(
                agent,
                10 ether
            );
        }


        vm.expectRevert(
            AgentIntentFirewall.DailyLimitExceeded.selector
        );


        firewall.authorize(
            agent,
            1 ether
        );
    }


    function test_Fuzz_AmountAboveLimitAlwaysFails(
        uint256 amount
    )
        public
    {
        vm.assume(
            amount > 10 ether
        );


        vm.expectRevert(
            AgentIntentFirewall.AmountExceeded.selector
        );


        firewall.authorize(
            agent,
            amount
        );
    }
}
