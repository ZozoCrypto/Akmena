// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../interfaces/IAgentPortfolioEngine.sol";

contract AgentPortfolioEngine is IAgentPortfolioEngine {
    error EmptyTitle();
    error EmptyURI();

    mapping(bytes32 => PortfolioItem[]) internal portfolios;

    function addPortfolioItem(bytes32 agentId, string calldata title, string calldata uri) external {
        if (bytes(title).length == 0) {
            revert EmptyTitle();
        }

        if (bytes(uri).length == 0) {
            revert EmptyURI();
        }

        portfolios[agentId].push(PortfolioItem({agentId: agentId, title: title, uri: uri, createdAt: block.timestamp}));

        emit PortfolioItemAdded(agentId, title, uri);
    }

    function getPortfolioItems(bytes32 agentId) external view returns (PortfolioItem[] memory) {
        return portfolios[agentId];
    }

    function portfolioCount(bytes32 agentId) external view returns (uint256) {
        return portfolios[agentId].length;
    }
}
