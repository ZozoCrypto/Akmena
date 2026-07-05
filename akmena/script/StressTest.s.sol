// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {AkmenaToken} from "../src/token/AkmenaToken.sol";
import {AkmenaEscrow} from "../src/escrow/AkmenaEscrow.sol";

contract StressTest is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        AkmenaToken token = AkmenaToken(0xDcA2BD782B616e5E50169cAaC38C53AC7cFbebe8);
        address escrow = 0x997C1fEfA2F3a25Eae12fE804858f6c04919c69c;

        vm.startBroadcast(deployerPrivateKey);

        for (uint i = 0; i < 50; i++) {
            // GUARANTEED UNIQUE: Keccak256 hash of the loop index and current block timestamp
            bytes32 taskId = keccak256(abi.encodePacked(i, block.timestamp, msg.sender));
            
            bytes memory data = abi.encode(taskId, address(0x2), msg.sender, 86400);
            
            token.transferAndCall(escrow, 1, data);
        }
        vm.stopBroadcast();
    }
}