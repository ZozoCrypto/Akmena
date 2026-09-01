// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {
    AkmenaCore
} from "../../../src/core/AkmenaCore.sol";

import {
    AkmenaPolicyBoundary
} from "../../../src/authorization/AkmenaPolicyBoundary.sol";

import {
    AkmenaExecutionAuthorization
} from "../../../src/authorization/AkmenaExecutionAuthorization.sol";

contract ReentrantExecutionTarget {
    AkmenaPolicyBoundary public boundary;

    AkmenaExecutionAuthorization.ExecutionIntent public nestedIntent;

    bytes public nestedPayload;
    bytes public nestedSignature;

    bool public attemptReentry;
    bool public reentrySucceeded;
    bool public reentryCompleted;

    uint256 public reentryCount;

    constructor(
        AkmenaPolicyBoundary boundary_
    ) {
        boundary = boundary_;
    }

    function configureReentry(
        AkmenaExecutionAuthorization.ExecutionIntent calldata intent,
        bytes calldata payload,
        bytes calldata signature
    ) external {
        nestedIntent = intent;
        nestedPayload = payload;
        nestedSignature = signature;
        attemptReentry = true;
    }

    function clearReentry() external {
        attemptReentry = false;
    }

    function execute() external payable returns (bool) {
        if (
            attemptReentry &&
            !reentryCompleted
        ) {
            reentryCount += 1;

            reentryCompleted = true;

            try boundary.executeAuthorizedAgentCall(
                nestedIntent,
                nestedPayload,
                nestedSignature
            ) returns (bytes memory) {
                reentrySucceeded = true;
            } catch {
                reentrySucceeded = false;
            }
        }

        return true;
    }
}

contract AttackProductionReentrancyTest is Test {
    AkmenaCore internal core;
    AkmenaPolicyBoundary internal boundary;
    ReentrantExecutionTarget internal target;

    uint256 internal constant AGENT_KEY =
        0xA11CE;

    address internal agent;
    address internal operator =
        address(0x1111);

    address internal recipient =
        address(0xBBBB);

    function setUp() public {
        core = new AkmenaCore();

        boundary =
            new AkmenaPolicyBoundary(
                address(core)
            );

        target =
            new ReentrantExecutionTarget(
                boundary
            );

        agent =
            vm.addr(AGENT_KEY);

        vm.prank(operator);

        boundary.setAgentPolicy(
            agent,
            20 ether,
            20 ether,
            false
        );
    }

    function _intent(
        uint256 amount,
        uint256 nonce
    )
        internal
        view
        returns (
            AkmenaExecutionAuthorization.ExecutionIntent memory
        )
    {
        bytes memory payload =
            abi.encodeWithSelector(
                ReentrantExecutionTarget.execute.selector
            );

        return
            AkmenaExecutionAuthorization.ExecutionIntent({
                operator: operator,
                agent: agent,
                target: address(target),
                selector:
                    ReentrantExecutionTarget.execute.selector,
                calldataHash:
                    keccak256(payload),
                amount: amount,
                value: 0,
                proofModuleKey: bytes32(0),
                proofId: 0,
                nonce: nonce,
                validAfter: block.timestamp,
                deadline: block.timestamp + 1 hours
            });
    }

    function _sign(
        AkmenaExecutionAuthorization.ExecutionIntent memory intent
    )
        internal
        view
        returns (bytes memory)
    {
        bytes32 digest =
            boundary.executionAuthorization().hashIntent(
                intent
            );

        (
            uint8 v,
            bytes32 r,
            bytes32 s
        ) =
            vm.sign(
                AGENT_KEY,
                digest
            );

        return abi.encodePacked(
            r,
            s,
            v
        );
    }

    function test_SameNonceReentryMustFail()
        public
    {
        uint256 amount = 1 ether;

        AkmenaExecutionAuthorization.ExecutionIntent
            memory intent =
                _intent(
                    amount,
                    0
                );

        bytes memory payload =
            abi.encodeWithSelector(
                ReentrantExecutionTarget.execute.selector
            );

        bytes memory signature =
            _sign(intent);

        target.configureReentry(
            intent,
            payload,
            signature
        );

        vm.prank(agent);

        boundary.executeAuthorizedAgentCall(
            intent,
            payload,
            signature
        );

        assertEq(
            target.reentryCount(),
            1
        );

        assertFalse(
            target.reentrySucceeded(),
            "CRITICAL: same nonce was replayable during reentrancy"
        );
    }

    function test_DifferentNonceReentryMustNotBypassDailyPolicy()
        public
    {
        // Daily limit is 20 ETH.
        // 12 ETH + 9 ETH = 21 ETH, so the nested
        // authorization must fail on cumulative policy.
        uint256 firstAmount = 12 ether;
        uint256 secondAmount = 9 ether;

        AkmenaExecutionAuthorization.ExecutionIntent
            memory first =
                _intent(
                    firstAmount,
                    0
                );

        AkmenaExecutionAuthorization.ExecutionIntent
            memory second =
                _intent(
                    secondAmount,
                    1
                );

        bytes memory payload =
            abi.encodeWithSelector(
                ReentrantExecutionTarget.execute.selector
            );

        bytes memory secondSignature =
            _sign(second);

        target.configureReentry(
            second,
            payload,
            secondSignature
        );

        bytes memory firstSignature =
            _sign(first);

        vm.prank(agent);

        boundary.executeAuthorizedAgentCall(
            first,
            payload,
            firstSignature
        );

        assertEq(
            target.reentryCount(),
            1
        );

        assertFalse(
            target.reentrySucceeded(),
            "CRITICAL: nested authorized spend bypassed daily policy"
        );
    }

    function test_SequentialAuthorizedSpendsRespectDailyPolicy()
        public
    {
        // Daily policy limit is 20 ETH.
        // First execution succeeds at 12 ETH.
        // Second execution would push cumulative spend
        // to 21 ETH and must therefore revert.
        uint256 firstAmount = 12 ether;
        uint256 secondAmount = 9 ether;

        AkmenaExecutionAuthorization.ExecutionIntent
            memory first =
                _intent(
                    firstAmount,
                    0
                );

        bytes memory payload =
            abi.encodeWithSelector(
                ReentrantExecutionTarget.execute.selector
            );

        bytes memory firstSignature =
            _sign(first);

        vm.prank(agent);

        boundary.executeAuthorizedAgentCall(
            first,
            payload,
            firstSignature
        );

        AkmenaExecutionAuthorization.ExecutionIntent
            memory second =
                _intent(
                    secondAmount,
                    1
                );

        bytes memory secondSignature =
            _sign(second);

        vm.prank(agent);

        vm.expectRevert(
            AkmenaPolicyBoundary.PolicyExceeded.selector
        );

        boundary.executeAuthorizedAgentCall(
            second,
            payload,
            secondSignature
        );
    }
}
