// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IAgentPortfolioEngine {
    struct PortfolioItem {
        bytes32 agentId;
        string title;
        string uri;
        uint256 createdAt;
    }

    event PortfolioItemAdded(bytes32 indexed agentId, string title, string uri);

    function addPortfolioItem(bytes32 agentId, string calldata title, string calldata uri) external;

    function getPortfolioItems(bytes32 agentId) external view returns (PortfolioItem[] memory);

    function portfolioCount(bytes32 agentId) external view returns (uint256);
}
