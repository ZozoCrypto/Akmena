// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AkmenaCore} from "../../../src/core/AkmenaCore.sol";

import {Test} from "forge-std/Test.sol";
import {AkmenaPolicyBoundary} from "../../../src/authorization/AkmenaPolicyBoundary.sol";
import {AkmenaExecutionAuthorization} from "../../../src/authorization/AkmenaExecutionAuthorization.sol";

contract ERC8021Target {
    bool public executed;

    function ping() external returns (bool) {
        executed = true;
        return true;
    }
}

contract Attack_CalldataSuffixTest is Test {
    AkmenaPolicyBoundary internal boundary;
    AkmenaCore internal core;
    ERC8021Target internal target;

    uint256 internal agentPk = 0xA11CE;
    address internal agent;

    function setUp() public {
        agent = vm.addr(agentPk);

        core = new AkmenaCore();

        boundary = new AkmenaPolicyBoundary(address(core));
        target = new ERC8021Target();

        // The agent/operator has an active execution policy.
        vm.prank(agent);
        boundary.setAgentPolicy(agent, 100 ether, 100 ether, false);
    }

    function _intent(uint256 amount, uint256 value, uint256 nonce)
        internal
        view
        returns (AkmenaExecutionAuthorization.ExecutionIntent memory)
    {
        bytes memory payload = abi.encodeWithSelector(ERC8021Target.ping.selector);

        return AkmenaExecutionAuthorization.ExecutionIntent({
            operator: agent,
            agent: agent,
            target: address(target),
            selector: ERC8021Target.ping.selector,
            asset: address(0),
            calldataHash: keccak256(payload),
            amount: amount,
            value: value,
            proofModuleKey: bytes32(0),
            proofId: 0,
            nonce: nonce,
            validAfter: block.timestamp,
            deadline: block.timestamp + 1 hours
        });
    }

    function _sign(AkmenaExecutionAuthorization.ExecutionIntent memory intent) internal view returns (bytes memory) {
        bytes32 digest = boundary.executionAuthorization().hashIntent(intent);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(agentPk, digest);

        return abi.encodePacked(r, s, v);
    }

    function test_ERC8021SuffixDoesNotDoSAuthorizedExecution() public {
        bytes memory payload = abi.encodeWithSelector(ERC8021Target.ping.selector);

        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _intent(1 ether, 0, 0);

        bytes memory signature = _sign(intent);

        /*
         * Construct the legitimate production call exactly as a wallet
         * would encode it, then append an ERC-8021-style data suffix.
         *
         * The suffix belongs to the OUTER transaction calldata.
         * It is not part of the signed execution payload.
         */
        bytes memory validCalldata =
            abi.encodeWithSelector(boundary.executeAuthorizedAgentCall.selector, intent, payload, signature);

        bytes memory maliciousCalldata =
            abi.encodePacked(validCalldata, bytes20(0x8021000000000000000000000000000000000000));

        vm.prank(agent);

        (bool success, bytes memory returnData) = address(boundary).call(maliciousCalldata);

        assertTrue(success, "ERC-8021-style outer calldata suffix caused execution DoS");

        assertTrue(target.executed(), "Authorized target was not executed");

        bytes memory targetReturnData = abi.decode(returnData, (bytes));

        assertTrue(abi.decode(targetReturnData, (bool)), "Target execution did not return true");
    }

    function test_MutatingAuthorizedPayloadStillFails() public {
        bytes memory authorizedPayload = abi.encodeWithSelector(ERC8021Target.ping.selector);

        bytes memory maliciousPayload = abi.encodeWithSelector(ERC8021Target.ping.selector, bytes("MALICIOUS"));

        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _intent(1 ether, 0, 1);

        // Sign the legitimate payload.
        intent.calldataHash = keccak256(authorizedPayload);

        bytes memory signature = _sign(intent);

        vm.prank(agent);

        vm.expectRevert(AkmenaExecutionAuthorization.InvalidCalldataHash.selector);

        boundary.executeAuthorizedAgentCall(intent, maliciousPayload, signature);

        assertFalse(target.executed(), "Target executed unauthorized payload");
    }
}
