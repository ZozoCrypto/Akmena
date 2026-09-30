// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaCore} from "../../src/core/AkmenaCore.sol";
import {AkmenaPolicyBoundary} from "../../src/authorization/AkmenaPolicyBoundary.sol";
import {AkmenaExecutionAuthorization} from "../../src/authorization/AkmenaExecutionAuthorization.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {TimelockController} from "../../lib/openzeppelin-contracts/contracts/governance/TimelockController.sol";

contract GovMockToken is ERC20 {
    constructor() ERC20("Gov", "GOV") {}
    function mint(address to, uint256 amt) external { _mint(to, amt); }
}

contract GovMockAdapter {
    uint256 public received;
    function execute(uint256 amount) external returns (bool) {
        received += amount;
        return true;
    }
}

/// @notice Phase 7 (G-7) governance tests: pause guardian, slow/fast allowlist
/// administration, and the full timelock migration simulation.
/// @dev Model D governance track, spec v1.2 §7.1.
contract Governance_Phase7Test is Test {
    uint256 internal constant OPERATOR_KEY = 0x0E7A71;
    uint256 internal constant AGENT_KEY = 0xA6E171;

    address internal operator;
    address internal agent;
    address internal guardian = address(0x6A9D1A);
    address internal multisig = address(0x9E57C);
    address internal rando = address(0xA4D0);

    AkmenaCore internal core;
    AkmenaPolicyBoundary internal boundary;
    AkmenaExecutionAuthorization internal authorization;
    GovMockToken internal token;
    GovMockAdapter internal adapter;

    function setUp() public {
        operator = vm.addr(OPERATOR_KEY);
        agent = vm.addr(AGENT_KEY);

        core = new AkmenaCore();
        boundary = new AkmenaPolicyBoundary(address(core));
        authorization = AkmenaExecutionAuthorization(boundary.executionAuthorization());
        token = new GovMockToken();
        adapter = new GovMockAdapter();

        token.mint(operator, 1000 ether);
        vm.startPrank(operator);
        token.approve(address(boundary), type(uint256).max);
        boundary.setAgentAssetPolicy(agent, address(token), 100 ether, 100 ether, false);
        vm.stopPrank();

        // Interim deployer admin: admit token, allowlist adapter.
        boundary.setStandardDebit(address(token), true);
        boundary.setEconomicAdapter(address(token), address(adapter), true);
    }

    // ------------------------------------------------------------------
    // Pause guardian
    // ------------------------------------------------------------------

    function test_GuardianCanPauseImmediately() public {
        core.setPauseGuardian(guardian);
        vm.prank(guardian);
        core.setPaused(true);
        assertTrue(core.isPaused());
    }

    function test_GuardianCannotUnpause() public {
        core.setPauseGuardian(guardian);
        vm.prank(guardian);
        core.setPaused(true);
        vm.prank(guardian);
        vm.expectRevert(AkmenaCore.UnauthorizedAccess.selector);
        core.setPaused(false);
        assertTrue(core.isPaused(), "must stay paused");
    }

    function test_DeployerCanPauseAndUnpause() public {
        core.setPauseGuardian(guardian);
        core.setPaused(true);
        assertTrue(core.isPaused());
        core.setPaused(false);
        assertFalse(core.isPaused());
    }

    function test_NonGuardianCannotPause() public {
        core.setPauseGuardian(guardian);
        vm.prank(rando);
        vm.expectRevert(AkmenaCore.UnauthorizedAccess.selector);
        core.setPaused(true);
        assertFalse(core.isPaused());
    }

    function test_OnlyDeployerSetsGuardian() public {
        vm.prank(rando);
        vm.expectRevert(AkmenaCore.UnauthorizedAccess.selector);
        core.setPauseGuardian(rando);
    }

    function test_GuardianRotation() public {
        address g2 = address(0x6A9D1B);
        core.setPauseGuardian(guardian);
        core.setPauseGuardian(g2);
        vm.prank(guardian);
        vm.expectRevert(AkmenaCore.UnauthorizedAccess.selector);
        core.setPaused(true);
        vm.prank(g2);
        core.setPaused(true);
        assertTrue(core.isPaused());
    }

    function test_PauseBlocksExecution() public {
        core.setPauseGuardian(guardian);
        vm.prank(guardian);
        core.setPaused(true);

        (AkmenaExecutionAuthorization.ExecutionIntent memory intent, bytes memory payload) =
            _intent(10 ether, 0);
        bytes memory sig = _sign(intent);
        vm.prank(agent);
        vm.expectRevert(AkmenaPolicyBoundary.ProtocolPaused.selector);
        boundary.executeAuthorizedAgentCall(intent, payload, sig);
    }

    function test_UnpauseRestoresExecution() public {
        core.setPauseGuardian(guardian);
        vm.prank(guardian);
        core.setPaused(true);
        core.setPaused(false);

        (AkmenaExecutionAuthorization.ExecutionIntent memory intent, bytes memory payload) =
            _intent(10 ether, 0);
        bytes memory sig = _sign(intent);
        vm.prank(agent);
        boundary.executeAuthorizedAgentCall(intent, payload, sig);
        assertEq(adapter.received(), 10 ether);
    }

    // ------------------------------------------------------------------
    // Slow/fast allowlist administration
    // ------------------------------------------------------------------

    function test_AllowlistAdminStartsAsDeployer() public view {
        assertEq(boundary.allowlistAdmin(), address(this));
        assertEq(boundary.emergencyAdmin(), address(this));
    }

    function test_NonAdminCannotAddAdapter() public {
        GovMockAdapter a2 = new GovMockAdapter();
        vm.prank(rando);
        vm.expectRevert(AkmenaPolicyBoundary.UnauthorizedAdapterAdmin.selector);
        boundary.setEconomicAdapter(address(token), address(a2), true);
    }

    function test_NonAdminCannotEmergencyRemove() public {
        vm.prank(rando);
        vm.expectRevert(AkmenaPolicyBoundary.UnauthorizedAdapterAdmin.selector);
        boundary.emergencyRemoveEconomicAdapter(address(token), address(adapter));
    }

    function test_EmergencyAdminCanRemoveButNotAdd() public {
        boundary.setEmergencyAdmin(multisig);

        vm.prank(multisig);
        boundary.emergencyRemoveEconomicAdapter(address(token), address(adapter));
        assertFalse(boundary.economicAdapters(address(token), address(adapter)));

        // Emergency path has no add power; slow path rejects non-admin.
        vm.prank(multisig);
        vm.expectRevert(AkmenaPolicyBoundary.UnauthorizedAdapterAdmin.selector);
        boundary.setEconomicAdapter(address(token), address(adapter), true);
    }

    function test_EmergencyRemoveIsFailClosed() public {
        (AkmenaExecutionAuthorization.ExecutionIntent memory intent, bytes memory payload) =
            _intent(10 ether, 0);
        bytes memory sig = _sign(intent);

        boundary.setEmergencyAdmin(multisig);
        vm.prank(multisig);
        boundary.emergencyRemoveEconomicAdapter(address(token), address(adapter));

        vm.prank(agent);
        vm.expectRevert(AkmenaPolicyBoundary.EconomicAdapterNotAllowed.selector);
        boundary.executeAuthorizedAgentCall(intent, payload, sig);
        assertFalse(authorization.usedNonces(agent, 0), "nonce must be unconsumed");
        assertEq(adapter.received(), 0, "no funds moved");
    }

    function test_EmergencyTokenRemovalIsFailClosed() public {
        (AkmenaExecutionAuthorization.ExecutionIntent memory intent, bytes memory payload) =
            _intent(10 ether, 0);
        bytes memory sig = _sign(intent);

        boundary.setEmergencyAdmin(multisig);
        vm.prank(multisig);
        boundary.emergencyRemoveStandardDebit(address(token));

        vm.prank(agent);
        vm.expectRevert(AkmenaPolicyBoundary.StandardDebitNotAdmitted.selector);
        boundary.executeAuthorizedAgentCall(intent, payload, sig);
        assertFalse(authorization.usedNonces(agent, 0), "nonce must be unconsumed");
    }

    function test_AdminTransferToZeroReverts() public {
        vm.expectRevert(AkmenaPolicyBoundary.InvalidAdmin.selector);
        boundary.setAllowlistAdmin(address(0));
        vm.expectRevert(AkmenaPolicyBoundary.InvalidAdmin.selector);
        boundary.setEmergencyAdmin(address(0));
    }

    function test_NonAdminCannotTransferAdmin() public {
        vm.prank(rando);
        vm.expectRevert(AkmenaPolicyBoundary.UnauthorizedAdapterAdmin.selector);
        boundary.setAllowlistAdmin(rando);
    }

    function test_AdminTransferEmitsEvents() public {
        vm.expectEmit(true, false, false, false);
        emit AkmenaPolicyBoundary.AllowlistAdminUpdated(multisig);
        boundary.setAllowlistAdmin(multisig);

        vm.expectEmit(true, false, false, false);
        emit AkmenaPolicyBoundary.EmergencyAdminUpdated(multisig);
        boundary.setEmergencyAdmin(multisig);
    }

    // ------------------------------------------------------------------
    // Full G-7 migration simulation: deployer -> timelock + multisig
    // ------------------------------------------------------------------

    function test_G7Migration_TimelockAdd_EmergencyRemove() public {
        // 1. Deploy timelock: multisig is proposer + canceller, 2-day delay.
        address[] memory proposers = new address[](1);
        proposers[0] = multisig;
        address[] memory executors = new address[](1);
        executors[0] = multisig;
        TimelockController timelock = new TimelockController(2 days, proposers, executors, address(0));

        // 2. Migrate: slow path -> timelock, fast path -> multisig.
        boundary.setAllowlistAdmin(address(timelock));
        boundary.setEmergencyAdmin(multisig);

        // 3. Deployer loses all allowlist power.
        GovMockAdapter a2 = new GovMockAdapter();
        vm.expectRevert(AkmenaPolicyBoundary.UnauthorizedAdapterAdmin.selector);
        boundary.setEconomicAdapter(address(token), address(a2), true);

        // 4. Emergency removal by multisig is immediate (no timelock).
        vm.prank(multisig);
        boundary.emergencyRemoveEconomicAdapter(address(token), address(adapter));
        assertFalse(boundary.economicAdapters(address(token), address(adapter)));

        // 5. Adapter ADD via timelock: schedule...
        bytes memory addCall = abi.encodeCall(
            AkmenaPolicyBoundary.setEconomicAdapter, (address(token), address(a2), true)
        );
        vm.prank(multisig);
        timelock.schedule(address(boundary), 0, addCall, bytes32(0), bytes32(uint256(1)), 2 days);

        // ...cannot execute before delay.
        vm.prank(multisig);
        vm.expectRevert();
        timelock.execute(address(boundary), 0, addCall, bytes32(0), bytes32(uint256(1)));

        // ...executes after delay.
        vm.warp(block.timestamp + 2 days + 1);
        vm.prank(multisig);
        timelock.execute(address(boundary), 0, addCall, bytes32(0), bytes32(uint256(1)));
        assertTrue(boundary.economicAdapters(address(token), address(a2)), "timelock add must land");
    }

    function test_G7Migration_TimelockAddCancellable() public {
        address[] memory proposers = new address[](1);
        proposers[0] = multisig;
        address[] memory executors = new address[](1);
        executors[0] = multisig;
        TimelockController timelock = new TimelockController(2 days, proposers, executors, address(0));
        boundary.setAllowlistAdmin(address(timelock));

        GovMockAdapter evil = new GovMockAdapter();
        bytes memory addCall = abi.encodeCall(
            AkmenaPolicyBoundary.setEconomicAdapter, (address(token), address(evil), true)
        );
        bytes32 id = timelock.hashOperation(
            address(boundary), 0, addCall, bytes32(0), bytes32(uint256(2))
        );
        vm.prank(multisig);
        timelock.schedule(address(boundary), 0, addCall, bytes32(0), bytes32(uint256(2)), 2 days);

        // Multisig cancels the malicious addition during the delay.
        vm.prank(multisig);
        timelock.cancel(id);

        vm.warp(block.timestamp + 2 days + 1);
        vm.prank(multisig);
        vm.expectRevert();
        timelock.execute(address(boundary), 0, addCall, bytes32(0), bytes32(uint256(2)));
        assertFalse(
            boundary.economicAdapters(address(token), address(evil)), "cancelled add must not land"
        );
    }

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------

    function _intent(uint256 amount, uint256 nonce)
        internal
        view
        returns (AkmenaExecutionAuthorization.ExecutionIntent memory intent, bytes memory payload)
    {
        payload = abi.encodeWithSelector(GovMockAdapter.execute.selector, amount);
        intent = AkmenaExecutionAuthorization.ExecutionIntent({
            operator: operator,
            agent: agent,
            target: address(adapter),
            selector: GovMockAdapter.execute.selector,
            asset: address(token),
            calldataHash: keccak256(payload),
            amount: amount,
            value: 0,
            proofModuleKey: bytes32(0),
            proofId: 0,
            nonce: nonce,
            // forge-lint: disable-next-line(environment-read-across-mutation)
            validAfter: block.timestamp,
            // forge-lint: disable-next-line(environment-read-across-mutation)
            deadline: block.timestamp + 1 hours
        });
    }

    function _sign(AkmenaExecutionAuthorization.ExecutionIntent memory intent)
        internal
        view
        returns (bytes memory)
    {
        bytes32 digest = authorization.hashIntent(intent);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(AGENT_KEY, digest);
        return abi.encodePacked(r, s, v);
    }
}
