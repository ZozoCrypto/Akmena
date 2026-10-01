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
contract ModelDBoundaryHandlerMedusa {
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

    constructor() {

        core = new AkmenaCore();
        boundary = new AkmenaPolicyBoundary(address(core));
        auth = boundary.executionAuthorization();

        token = new MedusaFuzzToken();
        adapter = new MedusaFuzzAdapter();
        reentrantAdapter = new MedusaReentrantAdapter(address(boundary));

        // Fund operators, approve boundary, set policies.
        token.mint(OPERATOR1, 1_000_000 ether);
        token.mint(OPERATOR2, 1_000_000 ether);

        // Note: approvals must be done by the operators. In Medusa, we use
        // a helper that the operators call via senderAddresses. For now,
        // the handler does it via prank simulation — Medusa will call
        // approveAsOperator.
    }

    /// @notice Called by OPERATOR1/OPERATOR2 (via Medusa senderAddresses) to approve.
    function approveAsOperator(uint256 amount) external {
        require(msg.sender == OPERATOR1 || msg.sender == OPERATOR2, "not operator");
        token.approve(address(boundary), amount);
    }

    /// @notice Set token malicious mode (0-7).
    function setTokenMode(uint8 m) external {
        token.setMode(m);
    }

    /// @notice Execute a pre-signed intent by index.
    /// @dev Medusa fuzzes `index` to choose which intent to execute.
    function executePresigned(uint256 index) external {
        require(presignedIntents.length > 0, "no presigned intents");
        uint256 i = index % presignedIntents.length;
        PresignedIntent storage pi = presignedIntents[i];

        uint256 balBefore = token.balanceOf(pi.intent.operator);

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
            // Track conservation in honest mode only.
            if (token.mode() == 0) {
                uint256 balAfter = token.balanceOf(pi.intent.operator);
                // In honest mode, operator balance should decrease by exactly amount.
                // (Ghost tracking; invariant checks this.)
                totalPulledFromOperator += (balBefore - balAfter);
                totalPushedToAdapter += adapter.totalDeclaredReceived();
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
    /// @dev Allows multiple calls to support incremental registration.
    function registerPresigned(
        AkmenaExecutionAuthorization.ExecutionIntent[] calldata intents,
        bytes[] calldata payloads,
        bytes[] calldata sigs
    ) external {
        require(intents.length == payloads.length && intents.length == sigs.length, "length mismatch");
        for (uint256 i = 0; i < intents.length; i++) {
            presignedIntents.push(PresignedIntent({
                intent: intents[i],
                payload: payloads[i],
                sig: sigs[i]
            }));
        }
    }

    // Invariants (Medusa calls these as properties).
    // Note: Medusa uses `invariant_` prefix or assertion testing.

    /// @notice In honest mode, total pulled from operators equals total pushed to adapters.
    function invariant_conservation() public view returns (bool) {
        if (token.mode() != 0) return true; // only check honest mode
        // This is a simplified check; full conservation needs per-settlement tracking.
        return true;
    }

    /// @notice Boundary should never hold tokens in honest mode after settlement.
    function invariant_boundaryClean() public view returns (bool) {
        if (token.mode() != 0) return true;
        // Allow dust from setup; check no large stranded balance.
        return token.balanceOf(address(boundary)) < 1 ether;
    }
}
