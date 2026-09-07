// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AkmenaCore} from "../../../src/core/AkmenaCore.sol";

import {Test} from "forge-std/Test.sol";

import {AkmenaPolicyBoundary} from "../../../src/authorization/AkmenaPolicyBoundary.sol";

import {AkmenaExecutionAuthorization} from "../../../src/authorization/AkmenaExecutionAuthorization.sol";

contract CalldataCanonicalizationTarget {
    address public lastRecipient;
    uint256 public lastAmount;
    uint256 public calls;

    function transferLike(address recipient, uint256 amount) external returns (bool) {
        lastRecipient = recipient;
        lastAmount = amount;
        calls++;

        return true;
    }
}

contract AttackCalldataCanonicalizationTest is Test {
    AkmenaPolicyBoundary internal boundary;
    AkmenaCore internal core;
    CalldataCanonicalizationTarget internal target;

    uint256 internal constant AGENT_KEY = 0xA11CE;

    address internal agent;
    address internal operator = address(0xBBBB);
    address internal recipient = address(0xCCCC);

    function setUp() public {
        core = new AkmenaCore();

        boundary = new AkmenaPolicyBoundary(address(core));

        target = new CalldataCanonicalizationTarget();

        agent = vm.addr(AGENT_KEY);

        vm.prank(operator);

        boundary.setAgentPolicy(agent, 20 ether, 20 ether, false);
    }

    function _intent(bytes memory payload, uint256 nonce)
        internal
        view
        returns (AkmenaExecutionAuthorization.ExecutionIntent memory)
    {
        return AkmenaExecutionAuthorization.ExecutionIntent({
            operator: operator,
            agent: agent,
            target: address(target),
            selector: CalldataCanonicalizationTarget.transferLike.selector,
            calldataHash: keccak256(payload),
            amount: 1 ether,
            value: 0,
            proofModuleKey: bytes32(0),
            proofId: 0,
            nonce: nonce,
            validAfter: block.timestamp,
            deadline: block.timestamp + 1 hours
        });
    }

    function _sign(AkmenaExecutionAuthorization.ExecutionIntent memory intent) internal view returns (bytes memory) {
        bytes32 digest = boundary.executionAuthorization().hashIntent(intent);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(AGENT_KEY, digest);

        return abi.encodePacked(r, s, v);
    }

    function test_StandardABIEncodingExecutes() public {
        bytes memory payload =
            abi.encodeWithSelector(CalldataCanonicalizationTarget.transferLike.selector, recipient, 1 ether);

        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _intent(payload, 0);

        bytes memory signature = _sign(intent);

        vm.prank(agent);

        boundary.executeAuthorizedAgentCall(intent, payload, signature);

        assertEq(target.calls(), 1);

        assertEq(target.lastRecipient(), recipient);

        assertEq(target.lastAmount(), 1 ether);
    }

    function test_EquivalentSemanticPayloadWithDifferentBytesIsRejected() public {
        bytes memory authorizedPayload =
            abi.encodeWithSelector(CalldataCanonicalizationTarget.transferLike.selector, recipient, 1 ether);

        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _intent(authorizedPayload, 0);

        bytes memory signature = _sign(intent);

        /*
         * Append trailing bytes to the authorized calldata.
         *
         * The ABI-decoded recipient/amount remain the same,
         * but the byte representation is different.
         */
        bytes memory mutatedPayload = bytes.concat(authorizedPayload, hex"deadbeef");

        vm.prank(agent);

        vm.expectRevert();

        boundary.executeAuthorizedAgentCall(intent, mutatedPayload, signature);

        assertEq(target.calls(), 0);
    }

    function test_SelectorMutationIsRejected() public {
        bytes memory authorizedPayload =
            abi.encodeWithSelector(CalldataCanonicalizationTarget.transferLike.selector, recipient, 1 ether);

        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _intent(authorizedPayload, 0);

        bytes memory signature = _sign(intent);

        bytes memory mutatedPayload = abi.encodeWithSelector(bytes4(0x00000000), recipient, 1 ether);

        vm.prank(agent);

        vm.expectRevert();

        boundary.executeAuthorizedAgentCall(intent, mutatedPayload, signature);

        assertEq(target.calls(), 0);
    }
}
