// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {AkmenaCore} from "../../../src/core/AkmenaCore.sol";
import {AkmenaPolicyBoundary} from "../../../src/authorization/AkmenaPolicyBoundary.sol";

contract StatefulTarget {
    function ping() external pure returns (bool) { return true; }
}

contract Attack_CalldataSuffixTest is Test {
    AkmenaCore core;
    AkmenaPolicyBoundary boundary;
    StatefulTarget target;

    address agent = address(0x2222);

    function setUp() public {
        core = new AkmenaCore();
        boundary = new AkmenaPolicyBoundary(address(core));
        target = new StatefulTarget();

        // 1. Agent sets their own policy
        vm.prank(agent);
        boundary.setAgentPolicy(agent, 100 ether, 100 ether, false);
    }

    function test_Attack_ERC8021DataSuffixInjection() public {
        // 2. Prank as the agent so msg.sender matches the policy
        vm.startPrank(agent);

        bytes memory innerPayload = abi.encodeWithSignature("ping()");
        
        bytes memory validCalldata = abi.encodeWithSignature(
            "executeAgentCall(address,address,uint256,bytes32,uint256,bytes)",
            agent, // operator matches agent
            address(target),
            1 ether,
            bytes32(0),
            0,
            innerPayload
        );

        bytes memory maliciousCalldata = abi.encodePacked(validCalldata, bytes20(0x8021000000000000000000000000000000000000));

        (bool success, ) = address(boundary).call(maliciousCalldata);
        
        assertTrue(success, "CRITICAL: Akmena reverted due to ERC-8021 data suffix (Smart Wallet DoS)!");
        vm.stopPrank();
    }
}
