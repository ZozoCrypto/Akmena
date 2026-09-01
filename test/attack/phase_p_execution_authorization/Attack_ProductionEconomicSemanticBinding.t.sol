// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {
    AkmenaExecutionAuthorization
} from "../../../src/authorization/AkmenaExecutionAuthorization.sol";

contract EconomicTarget {
    uint256 public lastTransferredAmount;
    address public lastRecipient;

    event EconomicAction(
        address indexed recipient,
        uint256 amount
    );

    function transferLike(
        address recipient,
        uint256 amount
    )
        external
        returns (bool)
    {
        lastRecipient = recipient;
        lastTransferredAmount = amount;

        emit EconomicAction(
            recipient,
            amount
        );

        return true;
    }
}

contract AttackProductionEconomicSemanticBindingTest is Test {
    AkmenaExecutionAuthorization internal authorization;
    EconomicTarget internal target;

    uint256 internal constant AGENT_KEY =
        0xA11CE;

    address internal agent;
    address internal operator =
        address(0xAAAA);

    address internal recipient =
        address(0xBBBB);

    bytes32 internal constant TYPEHASH =
        keccak256(
            "ExecutionIntent(address operator,address agent,address target,address selector,bytes32 calldataHash,uint256 amount,uint256 value,bytes32 proofModuleKey,uint256 proofId,uint256 nonce,uint256 validAfter,uint256 deadline)"
        );

    function setUp() public {
        authorization =
            new AkmenaExecutionAuthorization();

        target =
            new EconomicTarget();

        agent =
            vm.addr(AGENT_KEY);
    }

    function _hashIntent(
        AkmenaExecutionAuthorization.ExecutionIntent memory intent
    )
        internal
        view
        returns (bytes32)
    {
        return authorization.hashIntent(intent);
    }

    function _sign(
        AkmenaExecutionAuthorization.ExecutionIntent memory intent
    )
        internal
        returns (bytes memory)
    {
        bytes32 digest =
            _hashIntent(intent);

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

    function test_DeclaredAmountAndPayloadAmountCanDiffer()
        public
    {
        uint256 declaredAmount =
            100 ether;

        uint256 payloadAmount =
            1000 ether;

        bytes memory payload =
            abi.encodeWithSelector(
                EconomicTarget.transferLike.selector,
                recipient,
                payloadAmount
            );

        AkmenaExecutionAuthorization.ExecutionIntent
            memory intent =
                AkmenaExecutionAuthorization.ExecutionIntent({
                    operator: operator,
                    agent: agent,
                    target: address(target),
                    selector: EconomicTarget.transferLike.selector,
                    calldataHash: keccak256(payload),
                    amount: declaredAmount,
                    value: 0,
                    proofModuleKey: bytes32(0),
                    proofId: 0,
                    nonce: 0,
                    validAfter: block.timestamp,
                    deadline: block.timestamp + 1 hours
                });

        bytes memory signature =
            _sign(intent);

        address signer =
            authorization.verifyAndConsume(
                intent,
                payload,
                0,
                signature
            );

        assertEq(
            signer,
            agent
        );

        (bool success, ) =
            address(target).call(
                payload
            );

        assertTrue(success);

        assertEq(
            target.lastTransferredAmount(),
            payloadAmount
        );

        assertEq(
            declaredAmount,
            100 ether
        );

        assertTrue(
            payloadAmount > declaredAmount
        );
    }
}
