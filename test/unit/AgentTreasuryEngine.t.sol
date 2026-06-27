// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../../src/treasury/AgentTreasuryEngine.sol";

contract AgentTreasuryEngineTest is Test {
    AgentTreasuryEngine engine;

    function setUp() public {
        engine = new AgentTreasuryEngine();
    }

    function testDeposit() public {
        engine.deposit(100);

        assertEq(engine.balance(), 100);
    }

    function testCannotDepositZero() public {
        vm.expectRevert();

        engine.deposit(0);
    }

    function testDepositsAccumulate() public {
        engine.deposit(100);
        engine.deposit(250);

        assertEq(engine.balance(), 350);
    }

    function testWithdraw() public {
        engine.deposit(500);

        engine.withdraw(200);

        assertEq(engine.balance(), 300);
    }

    function testCannotWithdrawZero() public {
        engine.deposit(100);

        vm.expectRevert();

        engine.withdraw(0);
    }

    function testCannotWithdrawMoreThanBalance() public {
        engine.deposit(100);

        vm.expectRevert();

        engine.withdraw(200);
    }

    function testTimestampUpdates() public {
        engine.deposit(100);

        IAgentTreasuryEngine.Treasury memory treasury = engine.getTreasury();

        assertGt(treasury.lastUpdated, 0);
    }

    function testTreasuryStoredCorrectly() public {
        engine.deposit(400);

        IAgentTreasuryEngine.Treasury memory treasury = engine.getTreasury();

        assertEq(treasury.balance, 400);
    }

    function testNewTreasuryStartsEmpty() public view {
        assertEq(engine.balance(), 0);
    }
}
