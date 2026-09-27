// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {AkmenaCore} from "../../../src/core/AkmenaCore.sol";
import {AkmenaPolicyBoundary} from "../../../src/authorization/AkmenaPolicyBoundary.sol";
import {AkmenaExecutionAuthorization} from "../../../src/authorization/AkmenaExecutionAuthorization.sol";

contract RedTeamNativeTarget {
    uint256 public received;

    function receivePayment() external payable {
        received += msg.value;
    }
}

contract RedTeamERC20 {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "insufficient");

        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;

        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "insufficient");
        require(allowance[from][msg.sender] >= amount, "allowance");

        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;

        return true;
    }
}

contract RedTeamEconomicAdapter {
    function drain(RedTeamERC20 token, address from, address to, uint256 amount) external {
        require(token.transferFrom(from, to, amount));
    }
}

contract AttackCriticalEconomicLimitBypassTest is Test {
    AkmenaCore internal core;
    AkmenaPolicyBoundary internal boundary;
    RedTeamNativeTarget internal nativeTarget;
    RedTeamERC20 internal token;
    RedTeamEconomicAdapter internal adapter;

    uint256 internal constant AGENT_PK = 0xA11CE;

    address internal agent;
    address internal operator = address(0x1111);
    address internal attacker = address(0xBEEF);

    function setUp() public {
        agent = vm.addr(AGENT_PK);

        core = new AkmenaCore();
        boundary = new AkmenaPolicyBoundary(address(core));

        nativeTarget = new RedTeamNativeTarget();
        token = new RedTeamERC20();
        adapter = new RedTeamEconomicAdapter();

        vm.deal(agent, 100 ether);

        vm.prank(operator);
        boundary.setAgentPolicy(agent, 1 ether, 1 ether, false);

        vm.prank(operator);
        boundary.setAgentAssetPolicy(agent, address(token), 1 ether, 1 ether, false);

        token.mint(address(boundary), 100 ether);

        // Give the adapter a standing allowance so the test exercises an
        // indirect transferFrom path rather than only direct token calls.
        vm.prank(address(boundary));
        token.approve(address(adapter), 100 ether);

        // The test contract is AkmenaCore's deployer in this fixture.
        boundary.setEconomicAdapter(address(token), address(adapter), true);
    }

    function _sign(AkmenaExecutionAuthorization.ExecutionIntent memory intent) internal view returns (bytes memory) {
        bytes32 digest = boundary.executionAuthorization().hashIntent(intent);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(AGENT_PK, digest);

        return abi.encodePacked(r, s, v);
    }

    function test_RedTeam_NativeValueExceedsPolicyReverts() public {
        uint256 declaredAmount = 1 ether;
        uint256 actualValue = 100 ether;

        bytes memory payload = abi.encodeWithSelector(nativeTarget.receivePayment.selector);

        AkmenaExecutionAuthorization.ExecutionIntent memory intent = AkmenaExecutionAuthorization.ExecutionIntent({
            operator: operator,
            agent: agent,
            target: address(nativeTarget),
            selector: nativeTarget.receivePayment.selector,
            calldataHash: keccak256(payload),
            asset: address(0),
            amount: declaredAmount,
            value: actualValue,
            proofModuleKey: bytes32(0),
            proofId: 0,
            nonce: 0,
            validAfter: block.timestamp,
            deadline: block.timestamp + 1 hours
        });

        bytes memory signature = _sign(intent);

        vm.prank(agent);
        vm.expectRevert(AkmenaPolicyBoundary.NativeValueMismatch.selector);

        boundary.executeAuthorizedAgentCall{value: actualValue}(intent, payload, signature);

        assertEq(nativeTarget.received(), 0);
    }

    function test_RedTeam_ERC20GenericExecutionReverts() public {
        uint256 declaredAmount = 1 ether;
        uint256 actualTransfer = 100 ether;

        bytes memory payload = abi.encodeWithSelector(RedTeamERC20.transfer.selector, attacker, actualTransfer);

        AkmenaExecutionAuthorization.ExecutionIntent memory intent = AkmenaExecutionAuthorization.ExecutionIntent({
            operator: operator,
            agent: agent,
            target: address(token),
            selector: RedTeamERC20.transfer.selector,
            calldataHash: keccak256(payload),
            asset: address(token),
            amount: declaredAmount,
            value: 0,
            proofModuleKey: bytes32(0),
            proofId: 0,
            nonce: 0,
            validAfter: block.timestamp,
            deadline: block.timestamp + 1 hours
        });

        bytes memory signature = _sign(intent);

        vm.prank(agent);
        vm.expectRevert(AkmenaPolicyBoundary.EconomicAdapterNotAllowed.selector);

        boundary.executeAuthorizedAgentCall(intent, payload, signature);

        assertEq(token.balanceOf(attacker), 0);
        assertEq(token.balanceOf(address(boundary)), 100 ether);
    }
}

contract AttackCriticalEconomicLimitBypassAdapterExtension is Test {
    uint256 internal constant AGENT_PK = 0xA11CE;

    address internal agent;
    address internal operator = address(0x1111);
    address internal attacker = address(0xBEEF);

    AkmenaCore internal core;
    AkmenaPolicyBoundary internal boundary;
    AkmenaExecutionAuthorization internal authorization;
    RedTeamERC20 internal token;
    RedTeamEconomicAdapter internal adapter;

    function setUp() public {
        agent = vm.addr(AGENT_PK);

        core = new AkmenaCore();
        boundary = new AkmenaPolicyBoundary(address(core));
        authorization = boundary.executionAuthorization();

        token = new RedTeamERC20();
        adapter = new RedTeamEconomicAdapter();

        vm.prank(operator);
        boundary.setAgentAssetPolicy(agent, address(token), 1 ether, 1 ether, false);

        token.mint(address(boundary), 100 ether);

        vm.prank(address(boundary));
        token.approve(address(adapter), 100 ether);

        boundary.setEconomicAdapter(address(token), address(adapter), true);
    }

    function _sign(AkmenaExecutionAuthorization.ExecutionIntent memory intent) internal view returns (bytes memory) {
        bytes32 digest = authorization.hashIntent(intent);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(AGENT_PK, digest);

        return abi.encodePacked(r, s, v);
    }

    function test_RedTeam_AllowlistedAdapterCannotExceedIntentAmount() public {
        uint256 declaredAmount = 1 ether;
        uint256 actualTransfer = 100 ether;

        bytes memory payload = abi.encodeWithSelector(
            RedTeamEconomicAdapter.drain.selector, token, address(boundary), attacker, actualTransfer
        );

        AkmenaExecutionAuthorization.ExecutionIntent memory intent = AkmenaExecutionAuthorization.ExecutionIntent({
            operator: operator,
            agent: agent,
            target: address(adapter),
            selector: RedTeamEconomicAdapter.drain.selector,
            calldataHash: keccak256(payload),
            asset: address(token),
            amount: declaredAmount,
            value: 0,
            proofModuleKey: bytes32(0),
            proofId: 0,
            nonce: 0,
            validAfter: block.timestamp,
            deadline: block.timestamp + 1 hours
        });

        bytes memory signature = _sign(intent);

        vm.prank(agent);
        vm.expectRevert(AkmenaPolicyBoundary.EconomicSpendExceedsIntent.selector);

        boundary.executeAuthorizedAgentCall(intent, payload, signature);

        // Entire transaction must roll back, including the attempted drain.
        assertEq(token.balanceOf(attacker), 0);
        assertEq(token.balanceOf(address(boundary)), 100 ether);
    }
}
