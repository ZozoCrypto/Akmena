// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {AkmenaCore} from "../../src/core/AkmenaCore.sol";
import {AkmenaPolicyBoundary} from "../../src/authorization/AkmenaPolicyBoundary.sol";

contract AkmenaPolicyBoundaryTest is Test {
    AkmenaCore internal core;
    AkmenaPolicyBoundary internal boundary;

    address internal humanOperator = address(0x111);
    address internal aiAgentHotWallet = address(0x222);

    function setUp() public {
        core = new AkmenaCore();
        boundary = new AkmenaPolicyBoundary(address(core));
    }

    function test_AI_Agent_Within_Limits() public {
        // Human sets a strict $100 per tx limit, $500 daily limit
        uint256 maxSpend = 100e18; 
        uint256 dailyLimit = 500e18;
        
        vm.prank(humanOperator);
        boundary.setAgentPolicy(aiAgentHotWallet, maxSpend, dailyLimit, false);

        // AI Agent attempts to spend $50 within limits (Valid)
        vm.prank(aiAgentHotWallet);
        bool success = boundary.validateAgentExecution(humanOperator, aiAgentHotWallet, 50e18, 0);
        
        assertTrue(success, "Execution should be allowed");
    }

    function test_AI_Agent_Rogue_Tx_Limit_Exceeded() public {
        uint256 maxSpend = 100e18; 
        uint256 dailyLimit = 500e18;
        
        vm.prank(humanOperator);
        boundary.setAgentPolicy(aiAgentHotWallet, maxSpend, dailyLimit, false);

        // AI Agent hallucinates or is hacked and tries to spend $1,000 in one tx
        vm.prank(aiAgentHotWallet);
        vm.expectRevert(bytes4(keccak256("PolicyExceeded()")));
        boundary.validateAgentExecution(humanOperator, aiAgentHotWallet, 1000e18, 0);
    }

    function test_AI_Agent_Rogue_Daily_Limit_Exceeded() public {
        uint256 maxSpend = 100e18; 
        uint256 dailyLimit = 150e18; // Only $150 allowed per day
        
        vm.prank(humanOperator);
        boundary.setAgentPolicy(aiAgentHotWallet, maxSpend, dailyLimit, false);

        // Tx 1: $100 (Passes)
        vm.prank(aiAgentHotWallet);
        boundary.validateAgentExecution(humanOperator, aiAgentHotWallet, 100e18, 0);

        // Tx 2: $100 (Fails - Exceeds daily limit of $150)
        vm.prank(aiAgentHotWallet);
        vm.expectRevert(bytes4(keccak256("PolicyExceeded()")));
        boundary.validateAgentExecution(humanOperator, aiAgentHotWallet, 100e18, 0);
    }
}
