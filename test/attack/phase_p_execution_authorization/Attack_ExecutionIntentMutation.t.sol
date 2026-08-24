// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

contract PhasePExecutionTarget {
    uint256 public calls;
    uint256 public total;

    function execute(uint256 amount) external {
        calls++;
        total += amount;
    }

    function privileged() external {
        calls++;
    }
}

contract Attack_ExecutionIntentMutationTest is Test {
    PhasePExecutionTarget internal targetA;
    PhasePExecutionTarget internal targetB;

    address internal constant OPERATOR =
        address(0x1111);

    address internal constant AGENT =
        address(0x2222);

    bytes32 internal constant INTENT_DOMAIN =
        keccak256("akmena.execution.intent");

    struct ExecutionIntent {
        address operator;
        address agent;
        address target;
        bytes4 selector;
        bytes32 calldataHash;
        uint256 amount;
        uint256 value;
        bytes32 proofModuleKey;
        uint256 proofId;
        uint256 nonce;
        uint256 deadline;
    }

    function setUp() public {
        targetA = new PhasePExecutionTarget();
        targetB = new PhasePExecutionTarget();
    }

    function _intent(
        address operator_,
        address agent_,
        address target_,
        bytes4 selector_,
        bytes32 calldataHash_,
        uint256 amount_,
        uint256 value_,
        bytes32 proofModuleKey_,
        uint256 proofId_,
        uint256 nonce_,
        uint256 deadline_
    ) internal pure returns (ExecutionIntent memory) {
        return ExecutionIntent({
            operator: operator_,
            agent: agent_,
            target: target_,
            selector: selector_,
            calldataHash: calldataHash_,
            amount: amount_,
            value: value_,
            proofModuleKey: proofModuleKey_,
            proofId: proofId_,
            nonce: nonce_,
            deadline: deadline_
        });
    }

    function _baseIntent()
        internal
        view
        returns (ExecutionIntent memory)
    {
        return _intent(
            OPERATOR,
            AGENT,
            address(targetA),
            PhasePExecutionTarget.execute.selector,
            keccak256(
                abi.encodeWithSelector(
                    PhasePExecutionTarget.execute.selector,
                    1 ether
                )
            ),
            1 ether,
            0,
            bytes32(0),
            0,
            1,
            block.timestamp + 1 hours
        );
    }

    function _intentHash(
        ExecutionIntent memory intent
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                INTENT_DOMAIN,
                intent.operator,
                intent.agent,
                intent.target,
                intent.selector,
                intent.calldataHash,
                intent.amount,
                intent.value,
                intent.proofModuleKey,
                intent.proofId,
                intent.nonce,
                intent.deadline
            )
        );
    }

    /*
     * First establish that the baseline itself is deterministic.
     */
    function test_IntentHash_IsDeterministic() public view {
        ExecutionIntent memory a = _baseIntent();
        ExecutionIntent memory b = _baseIntent();

        assertEq(
            _intentHash(a),
            _intentHash(b),
            "IDENTICAL INTENTS MUST HASH IDENTICALLY"
        );
    }

    function test_Attack_MutateOperatorChangesIntent() public view {
        ExecutionIntent memory original = _baseIntent();

        ExecutionIntent memory mutated = _intent(
            address(0x9999),
            original.agent,
            original.target,
            original.selector,
            original.calldataHash,
            original.amount,
            original.value,
            original.proofModuleKey,
            original.proofId,
            original.nonce,
            original.deadline
        );

        assertTrue(
            _intentHash(original) != _intentHash(mutated),
            "CRITICAL: operator mutation did not change authorization"
        );
    }

    function test_Attack_MutateAgentChangesIntent() public view {
        ExecutionIntent memory original = _baseIntent();

        ExecutionIntent memory mutated = _intent(
            original.operator,
            address(0x9999),
            original.target,
            original.selector,
            original.calldataHash,
            original.amount,
            original.value,
            original.proofModuleKey,
            original.proofId,
            original.nonce,
            original.deadline
        );

        assertTrue(
            _intentHash(original) != _intentHash(mutated),
            "CRITICAL: agent mutation did not change authorization"
        );
    }

    function test_Attack_MutateTargetChangesIntent() public view {
        ExecutionIntent memory original = _baseIntent();

        ExecutionIntent memory mutated = _intent(
            original.operator,
            original.agent,
            address(targetB),
            original.selector,
            original.calldataHash,
            original.amount,
            original.value,
            original.proofModuleKey,
            original.proofId,
            original.nonce,
            original.deadline
        );

        assertTrue(
            _intentHash(original) != _intentHash(mutated),
            "CRITICAL: target mutation did not change authorization"
        );
    }

    function test_Attack_MutateSelectorChangesIntent() public view {
        ExecutionIntent memory original = _baseIntent();

        ExecutionIntent memory mutated = _intent(
            original.operator,
            original.agent,
            original.target,
            PhasePExecutionTarget.privileged.selector,
            original.calldataHash,
            original.amount,
            original.value,
            original.proofModuleKey,
            original.proofId,
            original.nonce,
            original.deadline
        );

        assertTrue(
            _intentHash(original) != _intentHash(mutated),
            "CRITICAL: selector mutation did not change authorization"
        );
    }

    function test_Attack_MutateCalldataChangesIntent() public view {
        ExecutionIntent memory original = _baseIntent();

        ExecutionIntent memory mutated = _intent(
            original.operator,
            original.agent,
            original.target,
            original.selector,
            keccak256(
                abi.encodeWithSelector(
                    PhasePExecutionTarget.execute.selector,
                    100 ether
                )
            ),
            original.amount,
            original.value,
            original.proofModuleKey,
            original.proofId,
            original.nonce,
            original.deadline
        );

        assertTrue(
            _intentHash(original) != _intentHash(mutated),
            "CRITICAL: calldata mutation did not change authorization"
        );
    }

    function test_Attack_MutateAmountChangesIntent() public view {
        ExecutionIntent memory original = _baseIntent();

        ExecutionIntent memory mutated = _intent(
            original.operator,
            original.agent,
            original.target,
            original.selector,
            original.calldataHash,
            100 ether,
            original.value,
            original.proofModuleKey,
            original.proofId,
            original.nonce,
            original.deadline
        );

        assertTrue(
            _intentHash(original) != _intentHash(mutated),
            "CRITICAL: amount mutation did not change authorization"
        );
    }

    function test_Attack_MutateValueChangesIntent() public view {
        ExecutionIntent memory original = _baseIntent();

        ExecutionIntent memory mutated = _intent(
            original.operator,
            original.agent,
            original.target,
            original.selector,
            original.calldataHash,
            original.amount,
            1 ether,
            original.proofModuleKey,
            original.proofId,
            original.nonce,
            original.deadline
        );

        assertTrue(
            _intentHash(original) != _intentHash(mutated),
            "CRITICAL: value mutation did not change authorization"
        );
    }

    function test_Attack_MutateProofDomainChangesIntent() public view {
        ExecutionIntent memory original = _baseIntent();

        ExecutionIntent memory mutated = _intent(
            original.operator,
            original.agent,
            original.target,
            original.selector,
            original.calldataHash,
            original.amount,
            original.value,
            keccak256("DIFFERENT_PROOF_DOMAIN"),
            original.proofId,
            original.nonce,
            original.deadline
        );

        assertTrue(
            _intentHash(original) != _intentHash(mutated),
            "CRITICAL: proof domain mutation did not change authorization"
        );
    }

    function test_Attack_MutateProofIdChangesIntent() public view {
        ExecutionIntent memory original = _baseIntent();

        ExecutionIntent memory mutated = _intent(
            original.operator,
            original.agent,
            original.target,
            original.selector,
            original.calldataHash,
            original.amount,
            original.value,
            original.proofModuleKey,
            999,
            original.nonce,
            original.deadline
        );

        assertTrue(
            _intentHash(original) != _intentHash(mutated),
            "CRITICAL: proof ID mutation did not change authorization"
        );
    }

    function test_Attack_MutateNonceChangesIntent() public view {
        ExecutionIntent memory original = _baseIntent();

        ExecutionIntent memory mutated = _intent(
            original.operator,
            original.agent,
            original.target,
            original.selector,
            original.calldataHash,
            original.amount,
            original.value,
            original.proofModuleKey,
            original.proofId,
            2,
            original.deadline
        );

        assertTrue(
            _intentHash(original) != _intentHash(mutated),
            "CRITICAL: nonce mutation did not change authorization"
        );
    }

    function test_Attack_MutateDeadlineChangesIntent() public view {
        ExecutionIntent memory original = _baseIntent();

        ExecutionIntent memory mutated = _intent(
            original.operator,
            original.agent,
            original.target,
            original.selector,
            original.calldataHash,
            original.amount,
            original.value,
            original.proofModuleKey,
            original.proofId,
            original.nonce,
            original.deadline + 1 hours
        );

        assertTrue(
            _intentHash(original) != _intentHash(mutated),
            "CRITICAL: deadline mutation did not change authorization"
        );
    }
}
