// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/core/AkmenaCore.sol";
import "../src/authorization/AkmenaPolicyBoundary.sol";
import "../src/authorization/AkmenaExecutionAuthorization.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

/// Minimal mock ERC20 used to stage the attacks.
contract MockERC20 {
    string public name = "Mock Token";
    string public symbol = "MCK";
    uint8 public decimals = 18;

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

/// Scenario (a)/(c): non-allowlisted malicious contract that drains via a
/// stale/confused ERC20 approval held by the boundary. msg.sender here is the
/// AkmenaPolicyBoundary.
contract Evil {
    function drain(address token, address to, uint256 amt) external {
        MockERC20(token).transferFrom(msg.sender, to, amt);
    }
}

/// Scenario (d): reentrant variant. Implements ERC-1271 so the boundary's
/// SignatureChecker accepts the inner intent whose agent is this contract
/// (the inner executeAuthorizedAgentCall runs with msg.sender == EvilReentrant).
contract EvilReentrant {
    AkmenaPolicyBoundary public boundary;
    bool public reentered;

    AkmenaExecutionAuthorization.ExecutionIntent public innerIntent;
    bytes public innerPayload;
    bytes public innerSig;

    constructor(address _boundary) {
        boundary = AkmenaPolicyBoundary(_boundary);
    }

    function setInnerCall(
        AkmenaExecutionAuthorization.ExecutionIntent calldata intent,
        bytes calldata payload,
        bytes calldata sig
    ) external {
        innerIntent = intent;
        innerPayload = payload;
        innerSig = sig;
    }

    // ERC-1271: accept any signature (adversarial contract).
    function isValidSignature(bytes32, bytes memory) external pure returns (bytes4) {
        return 0x1626ba7e;
    }

    function noop() external {}

    function attackDrain(address token, address to, uint256 amt) external {
        // Reenter the boundary BEFORE the draining transfer.
        boundary.executeAuthorizedAgentCall(innerIntent, innerPayload, innerSig);
        reentered = true;
        MockERC20(token).transferFrom(msg.sender, to, amt);
    }
}

/// Adversarial PoC — Scenario 2: Allowance-drain backstop.
///
/// Tests whether the post-call ERC20 accounting backstop in
/// AkmenaPolicyBoundary.executeAuthorizedAgentCall rolls back token theft
/// when a non-allowlisted target drains boundary custody via transferFrom
/// (e.g. a stale/confused approval).
contract AdapterAllowanceDrain is Test {
    uint256 constant AGENT_KEY = 0xA9E57;
    address agent;
    address attacker = address(0xA77AC4E2);

    AkmenaCore core;
    AkmenaPolicyBoundary boundary;
    AkmenaExecutionAuthorization auth;

    MockERC20 tokenA;
    MockERC20 tokenB;
    Evil evil;

    uint256 nonce;

    function setUp() public {
        agent = vm.addr(AGENT_KEY);

        // Shared setup (exactly as specified).
        core = new AkmenaCore();
        boundary = new AkmenaPolicyBoundary(address(core));
        auth = boundary.executionAuthorization();

        tokenA = new MockERC20();
        tokenB = new MockERC20();
        evil = new Evil();

        tokenA.mint(address(this), 2000e18);
        tokenB.mint(address(this), 2000e18);

        // Boundary holds 1000e18 of tokenA (attack asset).
        tokenA.transfer(address(boundary), 1000e18);
        tokenB.transfer(address(boundary), 100e18);

        nonce = 1;
    }

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------

    function _selector(bytes memory p) internal pure returns (bytes4 s) {
        assembly {
            s := mload(add(p, 32))
        }
    }

    function _baseIntent() internal view returns (AkmenaExecutionAuthorization.ExecutionIntent memory i) {
        i.operator = address(this);
        i.agent = agent;
        i.proofModuleKey = bytes32(0);
        i.proofId = 0;
        i.validAfter = 0;
        // forge-lint: disable-next-line(block-timestamp)
        i.deadline = block.timestamp + 7 days;
    }

    function _sign(AkmenaExecutionAuthorization.ExecutionIntent memory intent)
        internal
        view
        returns (bytes memory sig)
    {
        bytes32 digest = auth.hashIntent(intent);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(AGENT_KEY, digest);
        sig = abi.encodePacked(r, s, v);
    }

    /// Stale/confused approval: boundary approves the malicious contract.
    function _approveEvil(MockERC20 t, Evil e) internal {
        vm.prank(address(boundary));
        t.approve(address(e), type(uint256).max);
    }

    // ------------------------------------------------------------------
    // (a) MAIN: non-allowlisted Evil drains via stale approval
    // ------------------------------------------------------------------
    function test_a_allowanceDrainBackstop() public {
        _approveEvil(tokenA, evil);

        // ERC20 policy for the agent on tokenA (requireEscrow=false).
        boundary.setAgentAssetPolicy(agent, address(tokenA), 1000e18, 1000e18, false);

        bytes memory payload = abi.encodeCall(Evil.drain, (address(tokenA), attacker, 500e18));

        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _baseIntent();
        intent.target = address(evil);
        intent.selector = _selector(payload);
        intent.calldataHash = keccak256(payload);
        intent.asset = address(tokenA);
        intent.amount = 500e18;
        intent.value = 0;
        intent.nonce = nonce++;

        bytes memory sig = _sign(intent);

        uint256 balBoundaryBefore = tokenA.balanceOf(address(boundary));
        uint256 balAttackerBefore = tokenA.balanceOf(attacker);
        emit log_named_uint("boundary bal before", balBoundaryBefore);
        emit log_named_uint("attacker bal before", balAttackerBefore);

        vm.prank(agent);
        vm.expectRevert(AkmenaPolicyBoundary.EconomicAdapterNotAllowed.selector);
        boundary.executeAuthorizedAgentCall(intent, payload, sig);

        uint256 balBoundaryAfter = tokenA.balanceOf(address(boundary));
        uint256 balAttackerAfter = tokenA.balanceOf(attacker);
        emit log_named_uint("boundary bal after", balBoundaryAfter);
        emit log_named_uint("attacker bal after", balAttackerAfter);

        // The whole tx (including Evil's transferFrom) rolled back.
        assertEq(balBoundaryAfter, 1000e18, "boundary balance changed");
        assertEq(balAttackerAfter, 0, "attacker received tokens");
    }

    // ------------------------------------------------------------------
    // (b) Direct-token variant: target == token
    // ------------------------------------------------------------------
    function test_b1_directTokenCallRevertsPreCall() public {
        boundary.setAgentAssetPolicy(agent, address(tokenA), 1000e18, 1000e18, false);

        bytes memory payload = abi.encodeCall(MockERC20.transfer, (attacker, 500e18));

        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _baseIntent();
        intent.target = address(tokenA); // target == asset
        intent.selector = _selector(payload);
        intent.calldataHash = keccak256(payload);
        intent.asset = address(tokenA);
        intent.amount = 500e18;
        intent.value = 0;
        intent.nonce = nonce++;

        bytes memory sig = _sign(intent);

        vm.prank(agent);
        vm.expectRevert(AkmenaPolicyBoundary.EconomicAdapterNotAllowed.selector);
        boundary.executeAuthorizedAgentCall(intent, payload, sig);

        assertEq(tokenA.balanceOf(address(boundary)), 1000e18, "boundary balance changed");
        assertEq(tokenA.balanceOf(attacker), 0, "attacker received tokens");
    }

    function test_b2_tokenAllowlistedAsOwnAdapter() public {
        // Explicit deployer trust: test contract IS core.deployer().
        assertEq(core.deployer(), address(this), "not deployer");
        boundary.setEconomicAdapter(address(tokenA), address(tokenA), true);
        assertTrue(boundary.economicAdapters(address(tokenA), address(tokenA)), "allowlist not set");

        boundary.setAgentAssetPolicy(agent, address(tokenA), 1000e18, 1000e18, false);

        bytes memory payload = abi.encodeCall(MockERC20.transfer, (attacker, 500e18));

        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _baseIntent();
        intent.target = address(tokenA);
        intent.selector = _selector(payload);
        intent.calldataHash = keccak256(payload);
        intent.asset = address(tokenA);
        intent.amount = 500e18;
        intent.value = 0;
        intent.nonce = nonce++;

        bytes memory sig = _sign(intent);

        uint256 balBoundaryBefore = tokenA.balanceOf(address(boundary));

        vm.prank(agent);
        boundary.executeAuthorizedAgentCall(intent, payload, sig);

        uint256 balBoundaryAfter = tokenA.balanceOf(address(boundary));
        uint256 balAttackerAfter = tokenA.balanceOf(attacker);
        emit log_named_uint("boundary bal before", balBoundaryBefore);
        emit log_named_uint("boundary bal after", balBoundaryAfter);
        emit log_named_uint("attacker bal after", balAttackerAfter);

        // Explicitly allowlisted: pre-call check passes, transfer executes,
        // post-call backstop is bypassed (isEconomicAdapter=true), measured
        // spend is policy-checked and recorded.
        assertEq(balAttackerAfter, 500e18, "attacker did not receive tokens");
        assertEq(balBoundaryAfter, 500e18, "boundary balance wrong");
        (,, uint256 totalSpentToday,,) = boundary.agentAssetPolicies(address(this), agent, address(tokenA));
        assertEq(totalSpentToday, 500e18, "policy spend not recorded");
    }

    // ------------------------------------------------------------------
    // (c) Cross-asset allowlist: Evil allowlisted for tokenB only, attack on A
    // ------------------------------------------------------------------
    function test_c_crossAssetAllowlist() public {
        _approveEvil(tokenA, evil);

        // Allowlist Evil for tokenB ONLY. economicAdapters is keyed asset=>adapter.
        boundary.setEconomicAdapter(address(tokenB), address(evil), true);
        assertTrue(boundary.economicAdapters(address(tokenB), address(evil)), "B allowlist not set");
        assertFalse(boundary.economicAdapters(address(tokenA), address(evil)), "A unexpectedly allowlisted");

        boundary.setAgentAssetPolicy(agent, address(tokenA), 1000e18, 1000e18, false);

        bytes memory payload = abi.encodeCall(Evil.drain, (address(tokenA), attacker, 500e18));

        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _baseIntent();
        intent.target = address(evil);
        intent.selector = _selector(payload);
        intent.calldataHash = keccak256(payload);
        intent.asset = address(tokenA);
        intent.amount = 500e18;
        intent.value = 0;
        intent.nonce = nonce++;

        bytes memory sig = _sign(intent);

        vm.prank(agent);
        vm.expectRevert(AkmenaPolicyBoundary.EconomicAdapterNotAllowed.selector);
        boundary.executeAuthorizedAgentCall(intent, payload, sig);

        assertEq(tokenA.balanceOf(address(boundary)), 1000e18, "boundary balance changed");
        assertEq(tokenA.balanceOf(attacker), 0, "attacker received tokens");
    }

    // ------------------------------------------------------------------
    // (d) Attempted reentry through Evil mid-call.
    //
    // ENV NOTE: the sibling-frame tstore case is broken in forge
    // 1.8.4-nightly (scratch-poc/TStoreXFrame.t.sol::test_CrossFrameTStoreTLoad
    // fails), but NESTED frames share transient storage correctly in this
    // build: the inner executeAuthorizedAgentCall below reverts with
    // ReentrancyGuardReentrantCall(), i.e. the guard empirically blocks the
    // actual reentrancy threat model here. On a real Cancun EVM the same
    // revert occurs. Either way the result is SAFE by code inspection:
    // executeAuthorizedAgentCall is nonReentrant, so the reentrant inner
    // call cannot execute.
    // ------------------------------------------------------------------
    function test_d_reentrantDrain() public {
        EvilReentrant evilR = new EvilReentrant(address(boundary));
        _approveEvil(tokenA, Evil(address(evilR)));

        // Native (zero-value) policy for the reentrant caller (msg.sender of
        // the inner call is EvilReentrant itself; it is ERC-1271-valid).
        boundary.setAgentPolicy(address(evilR), 100e18, 1000e18, false);

        // Inner intent: zero-value native generic call, agent == EvilReentrant.
        bytes memory innerPayload = abi.encodeCall(EvilReentrant.noop, ());
        AkmenaExecutionAuthorization.ExecutionIntent memory inner = _baseIntent();
        inner.agent = address(evilR);
        inner.target = address(evilR);
        inner.selector = _selector(innerPayload);
        inner.calldataHash = keccak256(innerPayload);
        inner.asset = address(0);
        inner.amount = 1;
        inner.value = 0;
        inner.nonce = 777;
        bytes memory innerSig = ""; // accepted via EvilReentrant.isValidSignature (ERC-1271)
        evilR.setInnerCall(inner, innerPayload, innerSig);

        // Outer intent: drain with amt=0 so the post-call backstop does NOT
        // revert the outer frame; any reentry flag survives to be observed.
        boundary.setAgentAssetPolicy(agent, address(tokenA), 1000e18, 1000e18, false);
        bytes memory payload = abi.encodeCall(EvilReentrant.attackDrain, (address(tokenA), attacker, 0));

        AkmenaExecutionAuthorization.ExecutionIntent memory intent = _baseIntent();
        intent.target = address(evilR);
        intent.selector = _selector(payload);
        intent.calldataHash = keccak256(payload);
        intent.asset = address(tokenA);
        intent.amount = 0;
        intent.value = 0;
        intent.nonce = nonce++;

        bytes memory sig = _sign(intent);

        vm.prank(agent);
        // The transient reentrancy guard blocks the nested inner call.
        vm.expectRevert(ReentrancyGuardTransient.ReentrancyGuardReentrantCall.selector);
        boundary.executeAuthorizedAgentCall(intent, payload, sig);

        emit log_named_string("reentered flag", evilR.reentered() ? "true" : "false");
        emit log_named_uint("inner nonce consumed", auth.usedNonces(address(evilR), 777) ? 1 : 0);

        // Reentry was blocked at the inner boundary entry: the inner intent
        // never executed (nonce not consumed) and the outer frame reverted
        // with it, so nothing moved.
        assertFalse(evilR.reentered(), "reentry executed despite guard");
        assertFalse(auth.usedNonces(address(evilR), 777), "inner intent executed");

        // Nothing was stolen.
        assertEq(tokenA.balanceOf(address(boundary)), 1000e18, "boundary balance changed");
        assertEq(tokenA.balanceOf(attacker), 0, "attacker received tokens");
    }
}
