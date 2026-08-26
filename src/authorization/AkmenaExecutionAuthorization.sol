// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

/**
 * @title AkmenaExecutionAuthorization
 * @notice Cryptographic authorization primitive for exact agent execution.
 *
 * Security invariant:
 *
 *     A valid authorization permits ONE exact execution intent.
 *
 * The authorization is bound to:
 *
 *     operator
 *     agent
 *     target
 *     selector
 *     calldata
 *     economic amount
 *     native value
 *     proof domain
 *     proof id
 *     nonce
 *     validity window
 *
 * It is intentionally independent from AkmenaPolicyBoundary.
 */
contract AkmenaExecutionAuthorization is EIP712 {
    using ECDSA for bytes32;

    bytes32 public constant EXECUTION_INTENT_TYPEHASH = keccak256(
        "ExecutionIntent(" "address operator," "address agent," "address target," "bytes4 selector,"
        "bytes32 calldataHash," "uint256 amount," "uint256 value," "bytes32 proofModuleKey," "uint256 proofId,"
        "uint256 nonce," "uint256 validAfter," "uint256 deadline" ")"
    );

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
        uint256 validAfter;
        uint256 deadline;
    }

    mapping(address => mapping(uint256 => bool)) public usedNonces;

    error InvalidSigner();
    error AuthorizationExpired();
    error AuthorizationNotYetValid();
    error NonceAlreadyUsed();
    error InvalidTarget();
    error InvalidAgent();
    error InvalidSelector();
    error InvalidCalldataHash();

    constructor() EIP712("AkmenaExecutionAuthorization", "1") {}

    /**
     * @notice Return the EIP-712 digest for an execution intent.
     */
    function hashIntent(ExecutionIntent memory intent) public view returns (bytes32) {
        bytes32 structHash = keccak256(
            abi.encode(
                EXECUTION_INTENT_TYPEHASH,
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
                intent.validAfter,
                intent.deadline
            )
        );

        return _hashTypedDataV4(structHash);
    }

    /**
     * @notice Verify and consume an exact execution authorization.
     *
     * IMPORTANT:
     * The calldata and selector are derived from the ACTUAL payload.
     * The caller cannot provide an independent calldata hash.
     */
    function verifyAndConsume(
        ExecutionIntent calldata intent,
        bytes calldata payload,
        uint256 actualValue,
        bytes calldata signature
    ) external returns (address signer) {
        if (intent.agent == address(0)) {
            revert InvalidAgent();
        }

        if (intent.target == address(0)) {
            revert InvalidTarget();
        }

        if (block.timestamp < intent.validAfter) {
            revert AuthorizationNotYetValid();
        }

        if (block.timestamp > intent.deadline) {
            revert AuthorizationExpired();
        }

        if (usedNonces[intent.agent][intent.nonce]) {
            revert NonceAlreadyUsed();
        }

        bytes4 actualSelector;

        if (payload.length < 4) {
            revert InvalidSelector();
        }

        assembly {
            actualSelector := calldataload(payload.offset)
        }

        if (actualSelector != intent.selector) {
            revert InvalidSelector();
        }

        bytes32 actualCalldataHash = keccak256(payload);

        if (actualCalldataHash != intent.calldataHash) {
            revert InvalidCalldataHash();
        }

        if (actualValue != intent.value) {
            revert InvalidCalldataHash();
        }

        bytes32 digest = hashIntent(intent);

        signer = digest.recover(signature);

        if (signer != intent.agent) {
            revert InvalidSigner();
        }

        usedNonces[intent.agent][intent.nonce] = true;
    }
}
