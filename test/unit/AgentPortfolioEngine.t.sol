// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../../src/portfolio/AgentPortfolioEngine.sol";

contract AgentPortfolioEngineTest is Test {
    AgentPortfolioEngine engine;

    bytes32 constant AGENT_A = keccak256("agent-a");
    bytes32 constant AGENT_B = keccak256("agent-b");

    function setUp() public {
        engine = new AgentPortfolioEngine();
    }

    function testAddPortfolioItem() public {
        engine.addPortfolioItem(AGENT_A, "AI Assistant", "ipfs://portfolio-1");

        assertEq(engine.portfolioCount(AGENT_A), 1);
    }

    function testCannotAddEmptyTitle() public {
        vm.expectRevert();

        engine.addPortfolioItem(AGENT_A, "", "ipfs://portfolio-1");
    }

    function testCannotAddEmptyURI() public {
        vm.expectRevert();

        engine.addPortfolioItem(AGENT_A, "AI Assistant", "");
    }

    function testPortfolioStoredCorrectly() public {
        engine.addPortfolioItem(AGENT_A, "AI Assistant", "ipfs://portfolio-1");

        IAgentPortfolioEngine.PortfolioItem[] memory items = engine.getPortfolioItems(AGENT_A);

        assertEq(items.length, 1);
        assertEq(items[0].agentId, AGENT_A);
        assertEq(items[0].title, "AI Assistant");
        assertEq(items[0].uri, "ipfs://portfolio-1");
    }

    function testPortfolioCountAccumulates() public {
        engine.addPortfolioItem(AGENT_A, "Project One", "ipfs://one");

        engine.addPortfolioItem(AGENT_A, "Project Two", "ipfs://two");

        assertEq(engine.portfolioCount(AGENT_A), 2);
    }

    function testDifferentAgentsHaveSeparatePortfolios() public {
        engine.addPortfolioItem(AGENT_A, "Project One", "ipfs://one");

        engine.addPortfolioItem(AGENT_B, "Project Two", "ipfs://two");

        assertEq(engine.portfolioCount(AGENT_A), 1);
        assertEq(engine.portfolioCount(AGENT_B), 1);
    }

    function testTimestampSet() public {
        engine.addPortfolioItem(AGENT_A, "Project One", "ipfs://one");

        IAgentPortfolioEngine.PortfolioItem[] memory items = engine.getPortfolioItems(AGENT_A);

        assertGt(items[0].createdAt, 0);
    }

    function testUnknownAgentReturnsEmptyPortfolio() public view {
        assertEq(engine.portfolioCount(AGENT_A), 0);
    }
}
