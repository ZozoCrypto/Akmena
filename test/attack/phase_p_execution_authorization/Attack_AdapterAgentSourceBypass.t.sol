// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {AkmenaCore} from "../../../src/core/AkmenaCore.sol";
import {AkmenaPolicyBoundary} from "../../../src/authorization/AkmenaPolicyBoundary.sol";
import {AkmenaExecutionAuthorization} from "../../../src/authorization/AkmenaExecutionAuthorization.sol";

contract SourceSubstitutionERC20 {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
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

contract SourceSubstitutionAdapter {
    function drainFrom(SourceSubstitutionERC20 token, address from, address to, uint256 amount) external {
        require(token.transferFrom(from, to, amount));
    }
}

contract AttackAdapterAgentSourceBypassTest is Test {
    uint256 internal constant AGENT_PK = 0xA11CE;

    address internal agent;
    address internal operator = address(0x1111);
    address internal attacker = address(0xBEEF);

    AkmenaCore internal core;
    AkmenaPolicyBoundary internal boundary;
    AkmenaExecutionAuthorization internal authorization;
    SourceSubstitutionERC20 internal token;
    SourceSubstitutionAdapter internal adapter;

    function setUp() public {
        agent = vm.addr(AGENT_PK);

        core = new AkmenaCore();
        boundary = new AkmenaPolicyBoundary(address(core));
        authorization = boundary.executionAuthorization();

        token = new SourceSubstitutionERC20();
        adapter = new SourceSubstitutionAdapter();

        vm.prank(operator);
        boundary.setAgentAssetPolicy(agent, address(token), 1 ether, 1 ether, false);

        // The agent owns the funds being attacked.
        token.mint(agent, 100 ether);

        // The agent has explicitly approved the adapter.
        vm.prank(agent);
        token.approve(address(adapter), 100 ether);

        // Core deployer authorizes the adapter as an economic path.
        boundary.setEconomicAdapter(address(token), address(adapter), true);
        boundary.setStandardDebit(address(token), true);
    }

    function _sign(AkmenaExecutionAuthorization.ExecutionIntent memory intent) internal view returns (bytes memory) {
        bytes32 digest = authorization.hashIntent(intent);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(AGENT_PK, digest);

        return abi.encodePacked(r, s, v);
    }

    function test_RedTeam_AdapterCanSpendAgentFundsWithoutBoundaryDelta() public {
        // Model D regression: the old confused-deputy path is closed. The
        // boundary pulls ONLY from intent.operator (0x1111), which never
        // approved the boundary — the agent's direct approval of the adapter
        // is a wallet-level grant the boundary cannot and does not use.
        uint256 declaredAmount = 1 ether;
        uint256 actualTransfer = 100 ether;

        bytes memory payload = abi.encodeWithSelector(
            SourceSubstitutionAdapter.drainFrom.selector, token, agent, attacker, actualTransfer
        );

        AkmenaExecutionAuthorization.ExecutionIntent memory intent = AkmenaExecutionAuthorization.ExecutionIntent({
            operator: operator,
            agent: agent,
            target: address(adapter),
            selector: SourceSubstitutionAdapter.drainFrom.selector,
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
        vm.expectRevert(AkmenaPolicyBoundary.InsufficientOperatorAllowance.selector);
        boundary.executeAuthorizedAgentCall(intent, payload, signature);

        // Nothing moved through the boundary: the operator never approved it.
        assertEq(token.balanceOf(attacker), 0, "no funds were drained");
        assertEq(token.balanceOf(agent), 100 ether, "agent funds untouched");

        (,, uint256 totalSpentToday,,) = boundary.agentAssetPolicies(operator, agent, address(token));

        assertEq(totalSpentToday, 0, "nothing executed, nothing charged");
    }
}
