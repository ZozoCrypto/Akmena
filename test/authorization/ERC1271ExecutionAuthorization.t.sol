// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaCore} from "../../src/core/AkmenaCore.sol";
import {AkmenaPolicyBoundary} from "../../src/authorization/AkmenaPolicyBoundary.sol";
import {AkmenaExecutionAuthorization} from "../../src/authorization/AkmenaExecutionAuthorization.sol";

contract ERC1271Target {
    uint256 public calls;

    function ping() external {
        calls++;
    }
}

contract MockERC1271Agent {
    bytes4 internal constant MAGICVALUE = 0x1626ba7e;

    bytes32 public approvedDigest;
    bytes32 public approvedSignatureHash;
    bool public signatureEnabled;

    function configure(bytes32 digest, bytes calldata signature) external {
        approvedDigest = digest;
        approvedSignatureHash = keccak256(signature);
        signatureEnabled = true;
    }

    function revoke() external {
        signatureEnabled = false;
    }

    function isValidSignature(bytes32 digest, bytes calldata signature) external view returns (bytes4) {
        if (signatureEnabled && digest == approvedDigest && keccak256(signature) == approvedSignatureHash) {
            return MAGICVALUE;
        }

        return 0xffffffff;
    }

    function execute(
        AkmenaPolicyBoundary boundary,
        AkmenaExecutionAuthorization.ExecutionIntent calldata intent,
        bytes calldata payload,
        bytes calldata signature
    ) external returns (bytes memory) {
        return boundary.executeAuthorizedAgentCall(intent, payload, signature);
    }
}

contract ERC1271ExecutionAuthorizationTest is Test {
    address internal constant OPERATOR = address(0x1111);
    address internal constant ATTACKER = address(0xBEEF);
    uint256 internal constant AMOUNT = 1 ether;

    AkmenaCore internal core;
    AkmenaPolicyBoundary internal boundary;
    AkmenaExecutionAuthorization internal authorization;
    MockERC1271Agent internal smartAgent;
    ERC1271Target internal target;

    function setUp() public {
        core = new AkmenaCore();
        boundary = new AkmenaPolicyBoundary(address(core));
        authorization = boundary.executionAuthorization();
        smartAgent = new MockERC1271Agent();
        target = new ERC1271Target();

        vm.prank(OPERATOR);
        boundary.setAgentPolicy(address(smartAgent), 10 ether, 10 ether, false);
    }

    function _payload() internal pure returns (bytes memory) {
        return abi.encodeWithSelector(ERC1271Target.ping.selector);
    }

    function _intent(uint256 nonce) internal view returns (AkmenaExecutionAuthorization.ExecutionIntent memory) {
        bytes memory payload = _payload();

        return AkmenaExecutionAuthorization.ExecutionIntent({
            operator: OPERATOR,
            agent: address(smartAgent),
            target: address(target),
            selector: ERC1271Target.ping.selector,
            asset: address(0),
            calldataHash: keccak256(payload),
            amount: AMOUNT,
            value: 0,
            proofModuleKey: bytes32(0),
            proofId: 0,
            nonce: nonce,
            validAfter: block.timestamp,
            deadline: block.timestamp + 1 hours
        });
    }

    function _spentToday() internal view returns (uint256) {
        (uint256 maxSpend, uint256 dailyLimit, uint256 spentToday, uint256 lastResetTimestamp, bool requireEscrow) =
            boundary.agentPolicies(OPERATOR, address(smartAgent));

        maxSpend;
        dailyLimit;
        lastResetTimestamp;
        requireEscrow;

        return spentToday;
    }

    function test_ValidERC1271AgentAuthorizationExecutes() public {
        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _intent(0);

        bytes memory payload = _payload();
        bytes memory signature = hex"1271";

        smartAgent.configure(authorization.hashIntent(intent), signature);

        smartAgent.execute(boundary, intent, payload, signature);

        assertEq(target.calls(), 1);
        assertTrue(authorization.usedNonces(address(smartAgent), 0));
        assertEq(_spentToday(), AMOUNT);
    }

    function test_RevokedERC1271AuthorizationCannotExecute() public {
        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _intent(0);

        bytes memory payload = _payload();
        bytes memory signature = hex"1271";

        smartAgent.configure(authorization.hashIntent(intent), signature);
        smartAgent.revoke();

        vm.expectRevert(AkmenaExecutionAuthorization.InvalidSigner.selector);

        smartAgent.execute(boundary, intent, payload, signature);

        assertEq(target.calls(), 0);
        assertFalse(authorization.usedNonces(address(smartAgent), 0));
        assertEq(_spentToday(), 0);
    }

    function test_ThirdPartyCannotRelaySmartAgentAuthorization() public {
        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _intent(0);

        bytes memory payload = _payload();
        bytes memory signature = hex"1271";

        smartAgent.configure(authorization.hashIntent(intent), signature);

        vm.prank(ATTACKER);
        vm.expectRevert(AkmenaPolicyBoundary.UnauthorizedAgent.selector);

        boundary.executeAuthorizedAgentCall(intent, payload, signature);

        assertEq(target.calls(), 0);
        assertFalse(authorization.usedNonces(address(smartAgent), 0));
        assertEq(_spentToday(), 0);
    }
}
