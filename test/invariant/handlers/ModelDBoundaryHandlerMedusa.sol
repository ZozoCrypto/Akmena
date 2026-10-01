// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AkmenaCore} from "../../../src/core/AkmenaCore.sol";
import {AkmenaPolicyBoundary} from "../../../src/authorization/AkmenaPolicyBoundary.sol";
import {AkmenaExecutionAuthorization} from "../../../src/authorization/AkmenaExecutionAuthorization.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @notice Fuzzable ERC20 with configurable adversarial transfer semantics.
/// @dev Modes: 0=honest, 1=over-pull, 2=silent-success, 3=short-delivery,
///      4=fee-on-transfer, 5=rebase, 6=blacklist, 7=pausable.
///      Medusa-compatible: no vm.* cheatcodes.
contract MedusaFuzzToken is ERC20 {
    uint8 public mode;
    uint256 public constant OVERPULL_BPS = 1000;
    uint256 public constant SHORTFALL_BPS = 1000;
    uint256 public constant FEE_BPS = 500;
    uint256 public constant REBASE_BPS = 500;
    mapping(address => bool) public blacklisted;
    bool public paused;
    uint256 internal _rebaseCounter;

    constructor() ERC20("MedusaFuzzToken", "MFZ") {}

    function mint(address to, uint256 amount) external { _mint(to, amount); }
    function setMode(uint8 m) external { require(m <= 7, "bad mode"); mode = m; }
    function setBlacklisted(address who, bool flag) external { blacklisted[who] = flag; }
    function setPaused(bool p) external { paused = p; }

    function transferFrom(address from, address to, uint256 amount)
        public override returns (bool)
    {
        if (mode == 7 && paused) revert("token paused");
        if (mode == 6 && (blacklisted[from] || blacklisted[to])) revert("blacklisted");
        if (mode == 1) {
            uint256 overpull = amount + (amount * OVERPULL_BPS / 10000);
            return super.transferFrom(from, to, overpull);
        } else if (mode == 2) {
            return true;
        }
        return super.transferFrom(from, to, amount);
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        if (mode == 7 && paused) revert("token paused");
        if (mode == 6 && (blacklisted[msg.sender] || blacklisted[to])) revert("blacklisted");
        if (mode == 2) {
            return true;
        } else if (mode == 3) {
            uint256 short = amount - (amount * SHORTFALL_BPS / 10000);
            return super.transfer(to, short);
        } else if (mode == 4) {
            uint256 fee = (amount * FEE_BPS / 10000);
            _burn(msg.sender, fee);
            return super.transfer(to, amount - fee);
        } else if (mode == 5) {
            _rebaseCounter++;
            uint256 delta = (amount * REBASE_BPS / 10000);
            if (_rebaseCounter % 2 == 0) {
                _mint(msg.sender, delta);
            } else {
                uint256 bal = balanceOf(msg.sender);
                _burn(msg.sender, delta > bal ? bal : delta);
            }
            return super.transfer(to, amount);
        }
        return super.transfer(to, amount);
    }
}

/// @notice Recording adapter for Medusa fuzzing.
/// @dev Medusa-compatible: no vm.* cheatcodes.
contract MedusaFuzzAdapter {
    uint256 public totalDeclaredReceived;
    mapping(address => uint256) public declaredFrom;

    function execute(uint256 amount) external returns (bool) {
        totalDeclaredReceived += amount;
        declaredFrom[msg.sender] += amount;
        return true;
    }
}

/// @notice Reentrant adapter that calls back into the boundary during settlement.
/// @dev Medusa-compatible: no vm.* cheatcodes.
contract MedusaReentrantAdapter {
    AkmenaPolicyBoundary public boundary;
    bool public reentered;
    bytes public reentryCalldata;

    constructor(address _boundary) { boundary = AkmenaPolicyBoundary(_boundary); }

    function setReentry(bytes calldata cd) external { reentryCalldata = cd; }

    function execute(uint256 amount) external returns (bool) {
        if (reentryCalldata.length > 0 && !reentered) {
            reentered = true;
            // solhint-disable-next-line avoid-low-level-calls
            (bool ok, ) = address(boundary).call(reentryCalldata);
            ok; // reentry may revert; we record the attempt
        }
        amount; // silence warning
        return true;
    }
}

/// @notice Medusa-compatible handler for R9 adversarial fuzzing.
/// @dev Replaces vm.addr with hardcoded addresses and vm.sign with
///      pre-generated signatures (see script/GenerateMedusaSignatures.s.sol).
///      The pre-signed intents cover a fixed set of (operator, agent, amount,
///      nonce) combinations. Medusa fuzzes token modes, governance actions,
///      and which pre-signed intent to execute.
///
///      AGENT DESIGN (ERC-1271): The boundary requires msg.sender ==
///      intent.agent. Since the handler is the caller, the handler itself is
///      the intent agent: intents carry intent.agent == address(this), and the
///      handler implements ERC-1271 isValidSignature, authorizing a digest iff
///      it was registered via registerPresigned. Spending policies are
///      therefore namespaced (operator, handler, token) and must be set by
///      the operators in the genesis setup phase (see MEDUSA_RUNBOOK.md).
///      Operator ERC20 approvals to the boundary are likewise genesis state.
contract ModelDBoundaryHandlerMedusa {
    /// @dev ERC-1271 magic value: isValidSignature must return this.
    bytes4 internal constant ERC1271_MAGIC = 0x1626ba7e;
    // Hardcoded addresses (computed via vm.addr in Foundry, then frozen).
    // OPERATOR1_KEY = 0x0E7A71, OPERATOR2_KEY = 0x0E7A72
    // AGENT1_KEY = 0xA6E171, AGENT2_KEY = 0xA6E172
    address public constant OPERATOR1 = 0x8872ee96A7a73c98B0909D827C391A4d21dFcf01;
    address public constant OPERATOR2 = 0xcD8410Cd2D27B6fd23369e38C4c732544D0D0f82;
    address public constant AGENT1 = 0xdCfC9F66072Ba917Ac73236880bC5B5E180a24ED;
    address public constant AGENT2 = 0x7BB1F7A4E39e14470cC769903490DF698AFFBBf3;

    AkmenaCore public core;
    AkmenaPolicyBoundary public boundary;
    AkmenaExecutionAuthorization public auth;
    MedusaFuzzToken public token;
    MedusaFuzzAdapter public adapter;
    MedusaReentrantAdapter public reentrantAdapter;

    // Pre-signed intents (generated by script/GenerateMedusaSignatures.s.sol).
    // Each entry: intent + signature + payload.
    struct PresignedIntent {
        AkmenaExecutionAuthorization.ExecutionIntent intent;
        bytes payload;
        bytes sig;
    }
    PresignedIntent[] public presignedIntents;

    // Ghost state for invariants.
    uint256 public successfulSettlements;
    uint256 public totalPulledFromOperator;
    uint256 public totalPushedToAdapter;
    uint256 public revertCount;
    uint256 internal _lastAdapterReceived;
    /// @dev Set once the token ever leaves honest mode: malicious modes can
    /// legitimately change supply (rebase/mint/burn), so the supply half of
    /// conservation is only checked on purely-honest runs.
    bool public everNonHonestMode;
    /// @dev Digests authorized via ERC-1271. Set at registration time.
    mapping(bytes32 => bool) public authorizedDigest;

    constructor() {

        core = new AkmenaCore();
        boundary = new AkmenaPolicyBoundary(address(core));
        auth = boundary.executionAuthorization();

        token = new MedusaFuzzToken();
        adapter = new MedusaFuzzAdapter();
        reentrantAdapter = new MedusaReentrantAdapter(address(boundary));

        // The handler is its own operator for self-contained fuzzing:
        // it mints to itself, approves the boundary, and sets its own
        // (handler, handler, token) spending policy. No external genesis
        // setup needed — every deployment is immediately fuzzable.
        token.mint(address(this), 2_000_000 ether);
        token.approve(address(boundary), type(uint256).max);
        boundary.setAgentAssetPolicy(
            address(this), address(token), 10_000 ether, 1_000_000 ether, false
        );

        // Admission + allowlist: the handler is the interim allowlistAdmin
        // (core.deployer() == address(this)), so it configures these directly.
        boundary.setStandardDebit(address(token), true);
        boundary.setEconomicAdapter(address(token), address(adapter), true);
        boundary.setEconomicAdapter(address(token), address(reentrantAdapter), true);

        // Self-register pre-signed intents: the handler is its own agent
        // (ERC-1271), so intents can be created in the constructor with
        // agent == address(this). This makes every deployment (Medusa, forge,
        // cast) immediately fuzzable without a separate registration step.
        _registerBuiltinIntents();
    }

    /// @dev Registers 8 intents (4 amounts × 2 nonce sets) with the handler as
    /// both operator and agent. Called from the constructor; the one-shot guard
    /// is bypassed here because registration happens atomically at deployment.
    function _registerBuiltinIntents() internal {
        uint256[4] memory amounts = [uint256(1 ether), uint256(10 ether), uint256(100 ether), uint256(1000 ether)];
        uint256 nonce = 0;
        for (uint256 a = 0; a < 4; a++) {
            bytes memory payload =
                abi.encodeWithSelector(MedusaFuzzAdapter.execute.selector, amounts[a]);
            AkmenaExecutionAuthorization.ExecutionIntent memory intent =
                AkmenaExecutionAuthorization.ExecutionIntent({
                    operator: address(this),
                    agent: address(this),
                    target: address(adapter),
                    selector: MedusaFuzzAdapter.execute.selector,
                    calldataHash: keccak256(payload),
                    asset: address(token),
                    amount: amounts[a],
                    value: 0,
                    proofModuleKey: bytes32(0),
                    proofId: 0,
                    nonce: nonce,
                    validAfter: 0,
                    deadline: block.timestamp + 30 days
                });
            bytes32 digest = auth.hashIntent(intent);
            authorizedDigest[digest] = true;
            presignedIntents.push(
                PresignedIntent({intent: intent, payload: payload, sig: new bytes(65)})
            );
            nonce++;
        }
        // Second set with different nonces (4 more, total 8).
        for (uint256 a = 0; a < 4; a++) {
            bytes memory payload =
                abi.encodeWithSelector(MedusaFuzzAdapter.execute.selector, amounts[a]);
            AkmenaExecutionAuthorization.ExecutionIntent memory intent =
                AkmenaExecutionAuthorization.ExecutionIntent({
                    operator: address(this),
                    agent: address(this),
                    target: address(adapter),
                    selector: MedusaFuzzAdapter.execute.selector,
                    calldataHash: keccak256(payload),
                    asset: address(token),
                    amount: amounts[a],
                    value: 0,
                    proofModuleKey: bytes32(0),
                    proofId: 0,
                    nonce: nonce,
                    validAfter: 0,
                    deadline: block.timestamp + 30 days
                });
            bytes32 digest = auth.hashIntent(intent);
            authorizedDigest[digest] = true;
            presignedIntents.push(
                PresignedIntent({intent: intent, payload: payload, sig: new bytes(65)})
            );
            nonce++;
        }
    }

    /// @notice ERC-1271: the handler is the intent agent. A digest is valid
    /// iff it was registered via registerPresigned.
    /// @dev Test-harness simplification: authorization is by digest registry,
    ///      not by ECDSA recovery. Production agents remain EOAs.
    function isValidSignature(bytes32 hash, bytes calldata) external view returns (bytes4) {
        if (authorizedDigest[hash]) return ERC1271_MAGIC;
        return 0xffffffff;
    }

    /// @notice Set token malicious mode (0-7).
    function setTokenMode(uint8 m) external {
        token.setMode(m);
        if (m != 0) everNonHonestMode = true;
    }

    /// @notice Execute a pre-signed intent by index.
    /// @dev Medusa fuzzes `index` to choose which intent to execute.
    ///      The handler is the caller AND the intent agent (ERC-1271), so the
    ///      boundary's msg.sender == intent.agent gate passes.
    function executePresigned(uint256 index) external {
        require(presignedIntents.length > 0, "no presigned intents");
        uint256 i = index % presignedIntents.length;
        PresignedIntent storage pi = presignedIntents[i];

        uint256 balBefore = token.balanceOf(pi.intent.operator);
        uint256 adapterBefore = adapter.totalDeclaredReceived();

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, ) = address(boundary).call(
            abi.encodeWithSelector(
                boundary.executeAuthorizedAgentCall.selector,
                pi.intent,
                pi.payload,
                pi.sig
            )
        );

        if (success) {
            successfulSettlements++;
            // Track conservation in honest mode only (delta-based: the
            // adapter's total is cumulative, so record the per-call delta).
            if (token.mode() == 0) {
                uint256 balAfter = token.balanceOf(pi.intent.operator);
                totalPulledFromOperator += (balBefore - balAfter);
                totalPushedToAdapter += (adapter.totalDeclaredReceived() - adapterBefore);
            }
        } else {
            revertCount++;
        }
    }

    /// @notice Governance: remove adapter from allowlist.
    function govRemoveAdapter() external {
        // solhint-disable-next-line avoid-low-level-calls
        (bool ok, ) = address(boundary).call(
            abi.encodeWithSelector(
                boundary.emergencyRemoveEconomicAdapter.selector,
                address(token),
                address(adapter)
            )
        );
        ok;
    }

    /// @notice Governance: add adapter to allowlist.
    function govAddAdapter() external {
        // solhint-disable-next-line avoid-low-level-calls
        (bool ok, ) = address(boundary).call(
            abi.encodeWithSelector(
                boundary.setEconomicAdapter.selector,
                address(token),
                address(adapter),
                true
            )
        );
        ok;
    }

    /// @notice Governance: pause/unpause.
    function govSetPaused(bool p) external {
        core.setPaused(p);
    }

    /// @notice Register pre-signed intents (called by generator script).
    /// @dev One-shot: after genesis setup the fixed-intent model must not be
    ///      distortable by the fuzzer. Later calls revert harmlessly.
    ///      Intents MUST carry intent.agent == address(this); the digest is
    ///      authorized for ERC-1271 at registration time.
    function registerPresigned(
        AkmenaExecutionAuthorization.ExecutionIntent[] calldata intents,
        bytes[] calldata payloads,
        bytes[] calldata sigs
    ) external {
        require(presignedIntents.length == 0, "already registered");
        require(intents.length == payloads.length && intents.length == sigs.length, "length mismatch");
        for (uint256 i = 0; i < intents.length; i++) {
            require(intents[i].agent == address(this), "agent must be handler");
            presignedIntents.push(PresignedIntent({
                intent: intents[i],
                payload: payloads[i],
                sig: sigs[i]
            }));
            authorizedDigest[auth.hashIntent(intents[i])] = true;
        }
    }

    // Invariants (Medusa calls these as properties).
    // Note: Medusa uses `invariant_` prefix or assertion testing.

    /// @notice In honest mode, operator funds pulled equal adapter funds pushed.
    /// On purely-honest runs (token never left mode 0), no tokens may be
    /// created or destroyed: operator balances + adapter balances == minted.
    /// @dev Non-vacuous: ghost counters are delta-tracked per settlement.
    function invariant_conservation() public view returns (bool) {
        if (token.mode() != 0) return true; // only check honest mode
        if (totalPulledFromOperator != totalPushedToAdapter) return false;
        if (everNonHonestMode) return true; // supply may have moved legitimately
        uint256 supply = token.balanceOf(address(this))
            + token.balanceOf(address(adapter))
            + token.balanceOf(address(reentrantAdapter))
            + token.balanceOf(address(boundary));
        return supply == 2_000_000 ether;
    }

    /// @notice The boundary must never retain ERC20 after settlement, in any
    /// token mode: Model D pulls from the operator and pushes to the adapter
    /// atomically; a non-zero boundary balance means funds got stuck.
    function invariant_boundaryClean() public view returns (bool) {
        return token.balanceOf(address(boundary)) == 0;
    }
}
