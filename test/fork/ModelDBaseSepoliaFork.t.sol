// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaCore} from "../../src/core/AkmenaCore.sol";
import {AkmenaPolicyBoundary} from "../../src/authorization/AkmenaPolicyBoundary.sol";
import {AkmenaExecutionAuthorization} from "../../src/authorization/AkmenaExecutionAuthorization.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice R12: Base Sepolia fork test for Model D settlement.
/// @dev Forks Base Sepolia (chain ID 84532) and runs a full Model D
///      settlement flow against REAL Base Sepolia USDC
///      (0x036CbD53842c5426634e7929541eC2318f3dCF7e).
///      This validates that the boundary works against real chain state:
///      real token bytecode, real block timestamps, real chain ID.
///      The test gracefully skips if the RPC is unreachable.
contract ForkAdapter {
    uint256 public received;
    function execute(uint256 amount) external returns (bool) {
        received += amount;
        return true;
    }
}

contract ModelDBaseSepoliaForkTest is Test {
    uint256 internal constant OPERATOR_KEY = 0x0E7A71;
    uint256 internal constant AGENT_KEY = 0xA6E171;

    address internal operator;
    address internal agent;

    // Base Sepolia canonical USDC (Circle)
    IERC20 internal constant USDC = IERC20(0x036CbD53842c5426634e7929541eC2318f3dCF7e);

    AkmenaCore internal core;
    AkmenaPolicyBoundary internal boundary;
    AkmenaExecutionAuthorization internal auth;
    ForkAdapter internal adapter;

    uint256 internal nonceCounter;

    function setUp() public {
        // Fork Base Sepolia. Skip if RPC is unreachable.
        try vm.createSelectFork("https://sepolia.base.org") {
            // Fork selected successfully
        } catch {
            vm.skip(true);
        }

        operator = vm.addr(OPERATOR_KEY);
        agent = vm.addr(AGENT_KEY);

        core = new AkmenaCore();
        boundary = new AkmenaPolicyBoundary(address(core));
        // The boundary deploys its own AkmenaExecutionAuthorization internally.
        // We must use that instance because the EIP-712 domain separator
        // binds to the specific contract address.
        auth = AkmenaExecutionAuthorization(address(boundary.executionAuthorization()));
        adapter = new ForkAdapter();

        // Fund operator with USDC using deal (works on fork)
        deal(address(USDC), operator, 1000 * 1e6); // 1000 USDC (6 decimals)

        vm.startPrank(operator);
        USDC.approve(address(boundary), type(uint256).max);
        boundary.setAgentAssetPolicy(agent, address(USDC), 100 * 1e6, 100 * 1e6, false);
        vm.stopPrank();

        // Admit USDC as standard debit, allowlist adapter
        boundary.setStandardDebit(address(USDC), true);
        boundary.setEconomicAdapter(address(USDC), address(adapter), true);
    }

    function test_ForkChainIdIsBaseSepolia() public view {
        assertEq(block.chainid, 84532, "Not on Base Sepolia fork");
    }

    function test_RealUSDCIsDeployed() public view {
        // USDC contract exists on Base Sepolia
        assertGt(address(USDC).code.length, 0, "USDC not deployed on fork");
    }

    function test_ModelDSettlementOnBaseSepoliaFork() public {
        uint256 amount = 10 * 1e6; // 10 USDC

        bytes memory payload = abi.encodeWithSelector(ForkAdapter.execute.selector, amount);

        AkmenaExecutionAuthorization.ExecutionIntent memory intent =
            AkmenaExecutionAuthorization.ExecutionIntent({
                operator: operator,
                agent: agent,
                target: address(adapter),
                selector: ForkAdapter.execute.selector,
                calldataHash: keccak256(payload),
                asset: address(USDC),
                amount: amount,
                value: 0,
                proofModuleKey: bytes32(0),
                proofId: 0,
                nonce: ++nonceCounter,
                validAfter: 0,
                deadline: block.timestamp + 1 days
            });

        bytes32 digest = auth.hashIntent(intent);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(AGENT_KEY, digest);
        bytes memory sig = abi.encodePacked(r, s, v);

        uint256 operatorBefore = USDC.balanceOf(operator);

        vm.prank(agent);
        boundary.executeAuthorizedAgentCall(intent, payload, sig);

        // Verify settlement: operator debited, adapter received
        assertEq(USDC.balanceOf(operator), operatorBefore - amount, "Operator not debited");
        assertEq(adapter.received(), amount, "Adapter did not receive funds");
        assertTrue(auth.usedNonces(agent, intent.nonce), "Nonce not consumed");
    }

    function test_PauseBlocksSettlementOnFork() public {
        core.setPaused(true);

        bytes memory payload = abi.encodeWithSelector(ForkAdapter.execute.selector, 1 * 1e6);
        AkmenaExecutionAuthorization.ExecutionIntent memory intent =
            AkmenaExecutionAuthorization.ExecutionIntent({
                operator: operator,
                agent: agent,
                target: address(adapter),
                selector: ForkAdapter.execute.selector,
                calldataHash: keccak256(payload),
                asset: address(USDC),
                amount: 1 * 1e6,
                value: 0,
                proofModuleKey: bytes32(0),
                proofId: 0,
                nonce: ++nonceCounter,
                validAfter: 0,
                deadline: block.timestamp + 1 days
            });

        bytes32 digest = auth.hashIntent(intent);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(AGENT_KEY, digest);
        bytes memory sig = abi.encodePacked(r, s, v);

        vm.prank(agent);
        vm.expectRevert();
        boundary.executeAuthorizedAgentCall(intent, payload, sig);
    }
}
