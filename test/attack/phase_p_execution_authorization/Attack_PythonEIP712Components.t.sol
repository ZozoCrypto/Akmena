// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaExecutionAuthorization} from "../../../src/authorization/AkmenaExecutionAuthorization.sol";

contract Attack_PythonEIP712ComponentsTest is Test {
    uint256 internal constant AGENT_KEY = 0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa;

    function test_EIP712ComponentVector() public {
        AkmenaExecutionAuthorization authorization = new AkmenaExecutionAuthorization();

        address agent = vm.addr(AGENT_KEY);
        address operator = address(0x1111);
        address target = address(0x2222);

        bytes4 selector = bytes4(0xfe0d94c1);

        bytes memory payload = hex"fe0d94c10000000000000000000000000000000000000000000000000de0b6b3a7640000";

        bytes32 calldataHash = keccak256(payload);
        bytes32 proofModuleKey = keccak256("PRODUCTION_PROOF");

        AkmenaExecutionAuthorization.ExecutionIntent memory intent = AkmenaExecutionAuthorization.ExecutionIntent({
            operator: operator,
            agent: agent,
            target: target,
            selector: selector,
            calldataHash: calldataHash,
            amount: 1 ether,
            value: 0,
            proofModuleKey: proofModuleKey,
            proofId: 0,
            nonce: 12345,
            validAfter: 1,
            deadline: 3600
        });

        bytes32 typeHash = authorization.EXECUTION_INTENT_TYPEHASH();

        bytes32 structHash = keccak256(
            abi.encode(
                typeHash,
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

        bytes32 digest = authorization.hashIntent(intent);

        (, string memory name, string memory version, uint256 chainId, address verifyingContract,,) =
            authorization.eip712Domain();

        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name)),
                keccak256(bytes(version)),
                chainId,
                verifyingContract
            )
        );

        emit log_string("=== COMPONENT VECTOR ===");

        emit log_string("TYPE_HASH");
        emit log_bytes32(typeHash);

        emit log_string("STRUCT_HASH");
        emit log_bytes32(structHash);

        emit log_string("DOMAIN_SEPARATOR");
        emit log_bytes32(domainSeparator);

        emit log_string("DIGEST");
        emit log_bytes32(digest);

        emit log_string("CHAIN_ID");
        emit log_uint(chainId);

        emit log_string("VERIFYING_CONTRACT");
        emit log_address(verifyingContract);

        assertEq(name, "AkmenaExecutionAuthorization");

        assertEq(version, "1");
    }
}
