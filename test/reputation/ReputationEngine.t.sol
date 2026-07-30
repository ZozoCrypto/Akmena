// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {ReputationEngine} from "../../src/reputation/ReputationEngine.sol";
import {IReputationEngine} from "../../src/reputation/IReputationEngine.sol";

contract ReputationEngineTest is Test {
    ReputationEngine public engine;
    address public agent = address(0x777);

    function setUp() public {
        engine = new ReputationEngine();
    }

    function test_UpdateAndGetScore() public {
        vm.expectEmit(true, true, true, true);
        emit IReputationEngine.ReputationUpdated(agent, 100);

        engine.updateScore(agent, 100);
        assertEq(engine.getScore(agent), 100);
    }

    function test_RevertWhen_ZeroAddress() public {
        vm.expectRevert(IReputationEngine.InvalidAddress.selector);
        engine.updateScore(address(0), 50);
    }
}
