// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IReputationEngine} from "./IReputationEngine.sol";
import {LibStorage} from "../storage/LibStorage.sol";

contract ReputationEngine is IReputationEngine {
    function updateScore(address agent, uint256 score) external override {
        if (agent == address(0)) revert InvalidAddress();

        LibStorage.ReputationStorage storage ds = LibStorage.reputation();
        ds.score[agent] = score;

        emit ReputationUpdated(agent, score);
    }

    function getScore(address agent) external view override returns (uint256) {
        return LibStorage.reputation().score[agent];
    }
}
