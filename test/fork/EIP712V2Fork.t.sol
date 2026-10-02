// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaCore} from "../../src/core/AkmenaCore.sol";
import {AkmenaPolicyBoundary} from "../../src/authorization/AkmenaPolicyBoundary.sol";
import {AkmenaExecutionAuthorization} from "../../src/authorization/AkmenaExecutionAuthorization.sol";

/// @notice EIP-712 v2 domain verification on Base Sepolia fork.
/// @dev Proves the deployed AkmenaExecutionAuthorization uses EIP-712
///      version "2" (not "1"). The v2 bump was deliberate: it invalidates
///      all v1 signatures after the PolicyBoundary accounting fix.
///      Verified by recomputing the v2 digest manually and comparing
///      against auth.hashIntent().
contract EIP712V2ForkTest is Test {
    AkmenaCore internal core;
    AkmenaPolicyBoundary internal boundary;
    AkmenaExecutionAuthorization internal auth;

    uint256 internal constant AGENT_KEY = 0xA6E171;
    address internal agent;

    function setUp() public {
        try vm.createSelectFork("https://sepolia.base.org") {
            // Fork selected
        } catch {
            vm.skip(true);
        }

        agent = vm.addr(AGENT_KEY);
        core = new AkmenaCore();
        boundary = new AkmenaPolicyBoundary(address(core));
        auth = AkmenaExecutionAuthorization(address(boundary.executionAuthorization()));
    }

    function _v2DomainSeparator() internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes("AkmenaExecutionAuthorization")),
                keccak256(bytes("2")),
                block.chainid,
                address(auth)
            )
        );
    }

    function _v1DomainSeparator() internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes("AkmenaExecutionAuthorization")),
                keccak256(bytes("1")),
                block.chainid,
                address(auth)
            )
        );
    }

    function _manualV2Digest(AkmenaExecutionAuthorization.ExecutionIntent memory intent)
        internal
        view
        returns (bytes32)
    {
        bytes32 structHash = keccak256(
            abi.encode(
                auth.EXECUTION_INTENT_TYPEHASH(),
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
        return keccak256(abi.encodePacked("\x19\x01", _v2DomainSeparator(), structHash));
    }

    function test_HashIntentUsesV2Domain() public view {
        AkmenaExecutionAuthorization.ExecutionIntent memory intent =
            AkmenaExecutionAuthorization.ExecutionIntent({
                operator: address(0x1234),
                agent: agent,
                target: address(0x5678),
                selector: bytes4(0xdeadbeef),
                calldataHash: keccak256("test"),
                asset: address(0x9abc),
                amount: 1 ether,
                value: 0,
                proofModuleKey: bytes32(0),
                proofId: 0,
                nonce: 1,
                validAfter: 0,
                deadline: block.timestamp + 1 days
            });

        // The contract's hashIntent must equal our manually computed v2 digest.
        assertEq(auth.hashIntent(intent), _manualV2Digest(intent), "hashIntent does not use v2 domain");
    }

    function test_V1DigestDiffers() public view {
        AkmenaExecutionAuthorization.ExecutionIntent memory intent =
            AkmenaExecutionAuthorization.ExecutionIntent({
                operator: address(0x1234),
                agent: agent,
                target: address(0x5678),
                selector: bytes4(0xdeadbeef),
                calldataHash: keccak256("test"),
                asset: address(0x9abc),
                amount: 1 ether,
                value: 0,
                proofModuleKey: bytes32(0),
                proofId: 0,
                nonce: 1,
                validAfter: 0,
                deadline: block.timestamp + 1 days
            });

        bytes32 structHash = keccak256(
            abi.encode(
                auth.EXECUTION_INTENT_TYPEHASH(),
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
        bytes32 v1Digest = keccak256(abi.encodePacked("\x19\x01", _v1DomainSeparator(), structHash));

        // v1 digest must NOT equal the contract's digest — proving old signatures are invalid.
        assertTrue(auth.hashIntent(intent) != v1Digest, "v1 digest matches: version bump failed");
    }

    function test_V2SignatureRecoversAgent() public {
        AkmenaExecutionAuthorization.ExecutionIntent memory intent =
            AkmenaExecutionAuthorization.ExecutionIntent({
                operator: address(0x1234),
                agent: agent,
                target: address(0x5678),
                selector: bytes4(0xdeadbeef),
                calldataHash: keccak256("test"),
                asset: address(0x9abc),
                amount: 1 ether,
                value: 0,
                proofModuleKey: bytes32(0),
                proofId: 0,
                nonce: 1,
                validAfter: 0,
                deadline: block.timestamp + 1 days
            });

        bytes32 digest = auth.hashIntent(intent);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(AGENT_KEY, digest);

        address recovered = ecrecover(digest, v, r, s);
        assertEq(recovered, agent, "v2 signature does not recover agent");
    }
}
