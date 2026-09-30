// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaExecutionAuthorization} from "../../../src/authorization/AkmenaExecutionAuthorization.sol";

/// @notice EIP-712 byte-compatibility: v2/13-field is canonical; v1 and
/// 12-field signatures are rejected.
/// @dev Spec §12 item 12. The v1→v2 bump invalidated old signatures by
/// design — this test proves the invalidation is real, not assumed.
contract EIP712ByteCompatTest is Test {
    AkmenaExecutionAuthorization internal auth;

    uint256 internal constant AGENT_KEY = 0xA6E171;
    address internal agent;

    // v2 domain as deployed.
    bytes32 internal v2DomainSeparator;

    // The 13-field typehash (must match the contract).
    bytes32 internal constant EXPECTED_TYPEHASH = keccak256(
        "ExecutionIntent(address operator,address agent,address target,bytes4 selector,"
        "bytes32 calldataHash,address asset,uint256 amount,uint256 value,bytes32 proofModuleKey,"
        "uint256 proofId,uint256 nonce,uint256 validAfter,uint256 deadline)"
    );

    // 12-field typehash (the old schema, missing one field — e.g. no proofId).
    bytes32 internal constant OLD_12F_TYPEHASH = keccak256(
        "ExecutionIntent(address operator,address agent,address target,bytes4 selector,"
        "bytes32 calldataHash,address asset,uint256 amount,uint256 value,bytes32 proofModuleKey,"
        "uint256 nonce,uint256 validAfter,uint256 deadline)"
    );

    function setUp() public {
        agent = vm.addr(AGENT_KEY);
        auth = new AkmenaExecutionAuthorization();
        // Compute the v2 domain separator (OZ EIP712 doesn't expose it publicly).
        v2DomainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("AkmenaExecutionAuthorization"),
                keccak256("2"),
                block.chainid,
                address(auth)
            )
        );
    }

    function _intent() internal view returns (AkmenaExecutionAuthorization.ExecutionIntent memory) {
        // Payload must start with the selector and hash to calldataHash.
        bytes memory payload = abi.encodePacked(bytes4(hex"12345678"), "payload-body");
        return AkmenaExecutionAuthorization.ExecutionIntent({
            operator: address(0x0E7A70),
            agent: agent,
            target: address(0x7A9767),
            selector: bytes4(hex"12345678"),
            calldataHash: keccak256(payload),
            asset: address(0xA55E7),
            amount: 100 ether,
            value: 0,
            proofModuleKey: bytes32(0),
            proofId: 0,
            nonce: 1,
            validAfter: 0,
            deadline: block.timestamp + 1 days
        });
    }

    function _payload() internal pure returns (bytes memory) {
        return abi.encodePacked(bytes4(hex"12345678"), "payload-body");
    }

    /// @notice The deployed typehash is exactly the 13-field schema.
    function test_TypehashIs13Field() public view {
        assertEq(auth.EXECUTION_INTENT_TYPEHASH(), EXPECTED_TYPEHASH, "must be 13-field");
        assertTrue(auth.EXECUTION_INTENT_TYPEHASH() != OLD_12F_TYPEHASH, "must differ from 12-field");
    }

    /// @notice The domain separator uses version "2" — verified by comparing
    /// the contract's actual digest output against the manually computed v2
    /// domain. If the contract used any other domain, the digests would differ.
    function test_DomainIsV2() public view {
        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _intent();

        bytes32 structHash = keccak256(
            abi.encode(
                EXPECTED_TYPEHASH,
                intent.operator,
                intent.agent,
                intent.target,
                intent.selector,
                intent.calldataHash,
                intent.asset,
                intent.amount,
                intent.value,
                intent.proofModuleKey,
                intent.proofId,
                intent.nonce,
                intent.validAfter,
                intent.deadline
            )
        );
        bytes32 manualDigest = keccak256(abi.encodePacked("\x19\x01", v2DomainSeparator, structHash));

        // The contract's hashIntent must match our v2-domain computation.
        // This proves the contract is actually using version "2".
        assertEq(auth.hashIntent(intent), manualDigest, "contract must use v2 domain");
    }

    /// @notice A signature created with the v1 domain (version "1") does NOT
    /// verify against the v2 contract. Old signatures are dead.
    function test_V1SignatureRejected() public {
        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _intent();

        // Construct the v1 domain separator (version "1", same contract).
        bytes32 v1Domain = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("AkmenaExecutionAuthorization"),
                keccak256("1"),
                block.chainid,
                address(auth)
            )
        );
        assertTrue(v1Domain != v2DomainSeparator, "v1 and v2 domains differ");

        // Sign the struct hash with the v1 domain.
        bytes32 structHash = keccak256(
            abi.encode(
                EXPECTED_TYPEHASH,
                intent.operator,
                intent.agent,
                intent.target,
                intent.selector,
                intent.calldataHash,
                intent.asset,
                intent.amount,
                intent.value,
                intent.proofModuleKey,
                intent.proofId,
                intent.nonce,
                intent.validAfter,
                intent.deadline
            )
        );
        bytes32 v1Digest = keccak256(abi.encodePacked("\x19\x01", v1Domain, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(AGENT_KEY, v1Digest);
        bytes memory v1Sig = abi.encodePacked(r, s, v);

        // The v2 contract computes a different digest → ecrecover yields a
        // different address → InvalidSigner. (Calldata hash must match first.)
        bytes memory payload = _payload();
        vm.expectRevert(AkmenaExecutionAuthorization.InvalidSigner.selector);
        auth.verifyAndConsume(intent, payload, 0, v1Sig);
    }

    /// @notice A signature created with the 12-field schema does NOT verify.
    /// Clients using the old field layout produce unverifiable intents.
    function test_12FieldSignatureRejected() public {
        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _intent();

        // 12-field struct hash (missing proofId).
        bytes32 structHash12 = keccak256(
            abi.encode(
                OLD_12F_TYPEHASH,
                intent.operator,
                intent.agent,
                intent.target,
                intent.selector,
                intent.calldataHash,
                intent.asset,
                intent.amount,
                intent.value,
                intent.proofModuleKey,
                // proofId omitted
                intent.nonce,
                intent.validAfter,
                intent.deadline
            )
        );
        bytes32 digest12 = keccak256(abi.encodePacked("\x19\x01", v2DomainSeparator, structHash12));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(AGENT_KEY, digest12);
        bytes memory sig12 = abi.encodePacked(r, s, v);

        bytes memory payload = _payload();
        vm.expectRevert(AkmenaExecutionAuthorization.InvalidSigner.selector);
        auth.verifyAndConsume(intent, payload, 0, sig12);
    }

    /// @notice The correct v2/13-field signature verifies (control test).
    function test_V2_13FieldSignatureVerifies() public {
        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _intent();
        bytes32 digest = auth.hashIntent(intent);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(AGENT_KEY, digest);
        bytes memory sig = abi.encodePacked(r, s, v);

        bytes memory payload = _payload();
        // Should not revert.
        auth.verifyAndConsume(intent, payload, 0, sig);
        assertTrue(auth.usedNonces(agent, 1), "nonce consumed");
    }
}
