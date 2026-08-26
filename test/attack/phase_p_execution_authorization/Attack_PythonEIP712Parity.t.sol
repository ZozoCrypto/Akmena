// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaExecutionAuthorization} from "../../../src/authorization/AkmenaExecutionAuthorization.sol";

contract Attack_PythonEIP712ParityTest is Test {
    uint256 internal constant AGENT_KEY = 0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa;

    function test_DefinitivePythonParityVector() public {
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

        bytes32 digest = authorization.hashIntent(intent);

        (, string memory name, string memory version, uint256 chainId, address verifyingContract,,) =
            authorization.eip712Domain();

        emit log_string("=== SOLIDITY PARITY VECTOR ===");
        emit log_address(agent);
        emit log_address(operator);
        emit log_address(target);
        emit log_bytes32(bytes32(selector));
        emit log_bytes32(calldataHash);
        emit log_bytes32(proofModuleKey);
        emit log_uint(1 ether);
        emit log_uint(0);
        emit log_uint(0);
        emit log_uint(12345);
        emit log_uint(1);
        emit log_uint(3600);

        emit log_string("=== SOLIDITY DOMAIN ===");
        emit log_string(name);
        emit log_string(version);
        emit log_uint(chainId);
        emit log_address(verifyingContract);

        emit log_string("=== SOLIDITY HASHES ===");
        emit log_bytes32(typeHash);
        emit log_bytes32(digest);

        assertEq(agent, vm.addr(AGENT_KEY), "agent derivation mismatch");

        assertEq(address(authorization), verifyingContract, "verifying contract mismatch");

        assertEq(name, "AkmenaExecutionAuthorization", "EIP712 name mismatch");

        assertEq(version, "1", "EIP712 version mismatch");
    }
}
