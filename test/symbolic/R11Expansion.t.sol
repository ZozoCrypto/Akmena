// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaCore} from "../../src/core/AkmenaCore.sol";
import {AkmenaPolicyBoundary} from "../../src/authorization/AkmenaPolicyBoundary.sol";
import {AkmenaExecutionAuthorization} from "../../src/authorization/AkmenaExecutionAuthorization.sol";
import {EscrowEngine} from "../../src/economics/EscrowEngine.sol";

/// @notice Minimal ERC20 for escrow symbolic tests.
contract SymMockToken {
    string public name = "SymMock";
    string public symbol = "SYM";
    uint8 public decimals = 18;
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
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

/// @notice Empty contract with code (for adapter/asset mocks).
contract SymCode { }

/// @title R11 Expansion: Halmos symbolic verification for escrow, accounting, governance
/// @notice Each check_* function is a symbolic property. Halmos treats parameters
///         as symbolic values and searches for counterexamples. No counterexample
///         = property holds for ALL inputs. Low-level calls are used because
///         Halmos does not support expectRevert.
contract R11Expansion is Test {
    AkmenaCore internal core;
    AkmenaPolicyBoundary internal boundary;
    AkmenaExecutionAuthorization internal auth;
    EscrowEngine internal escrowEngine;
    SymMockToken internal token;
    SymCode internal mockAsset;
    SymCode internal mockAdapter;

    address internal operator = address(0x0BEA);
    address internal agent = address(0xA6E);

    function setUp() public {
        core = new AkmenaCore();
        boundary = new AkmenaPolicyBoundary(address(core));
        auth = AkmenaExecutionAuthorization(boundary.executionAuthorization());
        token = new SymMockToken();
        escrowEngine = new EscrowEngine(address(token));
        mockAsset = new SymCode();
        mockAdapter = new SymCode();
    }

    // ============ ESCROW PROPERTIES ============

    /// @notice SYMBOLIC: releaseEscrow MUST revert for any caller that is not the buyer.
    /// @dev The test contract is the buyer (createEscrow requires msg.sender == buyer).
    ///      A symbolic non-buyer caller attempts release via prank + low-level call.
    function check_ReleaseOnlyByBuyer(address caller, uint256 amount) public {
        vm.assume(caller != address(this));
        vm.assume(amount > 0 && amount < 1e30);

        address seller = address(0x5E11);

        token.mint(address(this), amount);
        token.approve(address(escrowEngine), amount);
        uint256 escrowId = escrowEngine.createEscrow(address(this), seller, address(token), amount);

        // Symbolic non-buyer attempts release
        vm.prank(caller);
        (bool success, ) = address(escrowEngine).call(
            abi.encodeWithSelector(escrowEngine.releaseEscrow.selector, escrowId)
        );

        // Property: MUST revert (only buyer can release)
        assertTrue(!success);
    }

    /// @notice SYMBOLIC: refundEscrow MUST revert for any caller that is not the seller.
    function check_RefundOnlyBySeller(address caller, uint256 amount) public {
        vm.assume(caller != address(0x5E11));
        vm.assume(amount > 0 && amount < 1e30);

        address seller = address(0x5E11);

        token.mint(address(this), amount);
        token.approve(address(escrowEngine), amount);
        uint256 escrowId = escrowEngine.createEscrow(address(this), seller, address(token), amount);

        // Symbolic non-seller attempts refund
        vm.prank(caller);
        (bool success, ) = address(escrowEngine).call(
            abi.encodeWithSelector(escrowEngine.refundEscrow.selector, escrowId)
        );

        // Property: MUST revert (only seller can refund)
        assertTrue(!success);
    }

    /// @notice SYMBOLIC: releaseEscrow MUST revert for a nonexistent escrow ID.
    function check_ReleaseNonexistentReverts(uint256 badId, address caller) public {
        vm.assume(badId >= 1000); // far beyond any created ID

        vm.prank(caller);
        (bool success, ) = address(escrowEngine).call(
            abi.encodeWithSelector(escrowEngine.releaseEscrow.selector, badId)
        );

        assertTrue(!success);
    }

    // ============ SETTLEMENT ACCOUNTING PROPERTIES ============

    /// @notice SYMBOLIC: zero-value native execution with amount exceeding the
    ///         daily limit MUST revert (headroom gate is enforced pre-signature).
    /// @dev The headroom check (line 464-472) runs BEFORE signature verification,
    ///      so this property holds regardless of signature validity. Uses a fresh
    ///      policy (totalSpentToday = 0), so headroom = dailyLimit.
    function check_ZeroValueNativeHeadroomGate(
        uint256 dailyLimit,
        uint256 amount,
        uint256 nonce,
        bytes memory payload,
        bytes memory signature
    ) public {
        vm.assume(dailyLimit < 1e30);
        vm.assume(amount > dailyLimit);

        // Fresh native policy: maxSpend = max (no interference), daily = symbolic
        vm.prank(operator);
        boundary.setAgentPolicy(agent, type(uint256).max, dailyLimit, false);

        AkmenaExecutionAuthorization.ExecutionIntent memory intent = AkmenaExecutionAuthorization.ExecutionIntent({
            operator: operator,
            agent: agent,
            target: address(mockAdapter),
            selector: bytes4(0),
            calldataHash: keccak256(payload),
            asset: address(0), // native
            amount: amount,
            value: 0,
            proofModuleKey: bytes32(0),
            proofId: 0,
            nonce: nonce,
            validAfter: 0,
            deadline: block.timestamp + 1 hours
        });

        (bool success, ) = address(boundary).call(
            abi.encodeWithSelector(
                boundary.executeAuthorizedAgentCall.selector,
                intent,
                payload,
                signature
            )
        );

        // Property: MUST revert (amount exceeds headroom)
        assertTrue(!success);
    }

    /// @notice SYMBOLIC: zero-value native execution with amount exceeding the
    ///         SATURATING headroom (dailyLimit - alreadySpent) MUST revert.
    /// @dev Sets totalSpentToday via vm.store to test the pre-spent path.
    ///      agentPolicies is at slot 0; totalSpentToday is field index 2.
    function check_ZeroValueNativeHeadroomPreSpent(
        uint256 dailyLimit,
        uint256 alreadySpent,
        uint256 amount,
        uint256 nonce,
        bytes memory payload,
        bytes memory signature
    ) public {
        vm.assume(dailyLimit < 1e30);
        vm.assume(alreadySpent <= dailyLimit);
        // Saturating headroom
        uint256 headroom = alreadySpent >= dailyLimit ? 0 : dailyLimit - alreadySpent;
        vm.assume(amount > headroom);
        // Avoid vacuous: there must exist an amount that exceeds headroom
        // (guaranteed since amount > headroom and headroom < 1e30)

        vm.prank(operator);
        boundary.setAgentPolicy(agent, type(uint256).max, dailyLimit, false);

        // Write totalSpentToday via vm.store
        // agentPolicies[operator][agent]: slot 0
        bytes32 mid = keccak256(abi.encode(operator, uint256(0)));
        bytes32 base = keccak256(abi.encode(agent, mid));
        bytes32 spentSlot = bytes32(uint256(base) + 2); // totalSpentToday is 3rd field
        vm.store(address(boundary), spentSlot, bytes32(alreadySpent));

        AkmenaExecutionAuthorization.ExecutionIntent memory intent = AkmenaExecutionAuthorization.ExecutionIntent({
            operator: operator,
            agent: agent,
            target: address(mockAdapter),
            selector: bytes4(0),
            calldataHash: keccak256(payload),
            asset: address(0),
            amount: amount,
            value: 0,
            proofModuleKey: bytes32(0),
            proofId: 0,
            nonce: nonce,
            validAfter: 0,
            deadline: block.timestamp + 1 hours
        });

        (bool success, ) = address(boundary).call(
            abi.encodeWithSelector(
                boundary.executeAuthorizedAgentCall.selector,
                intent,
                payload,
                signature
            )
        );

        assertTrue(!success);
    }

    // ============ GOVERNANCE PROPERTIES ============

    /// @notice SYMBOLIC: setEconomicAdapter (add) MUST revert for any caller
    ///         that is not the allowlistAdmin.
    function check_OnlyAllowlistAdminCanAddAdapter(address caller) public {
        address admin = boundary.allowlistAdmin();
        vm.assume(caller != admin);

        vm.prank(caller);
        (bool success, ) = address(boundary).call(
            abi.encodeWithSelector(
                boundary.setEconomicAdapter.selector,
                address(mockAsset),
                address(mockAdapter),
                true
            )
        );

        // Property: MUST revert (only allowlistAdmin can add)
        assertTrue(!success);
    }

    /// @notice SYMBOLIC: emergencyRemoveEconomicAdapter MUST revert for any
    ///         caller that is not the emergencyAdmin.
    function check_OnlyEmergencyAdminCanRemoveAdapter(address caller) public {
        address admin = boundary.emergencyAdmin();
        vm.assume(caller != admin);

        vm.prank(caller);
        (bool success, ) = address(boundary).call(
            abi.encodeWithSelector(
                boundary.emergencyRemoveEconomicAdapter.selector,
                address(mockAsset),
                address(mockAdapter)
            )
        );

        assertTrue(!success);
    }

    /// @notice SYMBOLIC: setAllowlistAdmin MUST revert for any caller that is
    ///         not the current allowlistAdmin.
    function check_OnlyAllowlistAdminCanTransferAdmin(address caller, address newAdmin) public {
        address admin = boundary.allowlistAdmin();
        vm.assume(caller != admin);
        vm.assume(newAdmin != address(0));

        vm.prank(caller);
        (bool success, ) = address(boundary).call(
            abi.encodeWithSelector(
                boundary.setAllowlistAdmin.selector,
                newAdmin
            )
        );

        assertTrue(!success);
    }

    /// @notice SYMBOLIC: setEmergencyAdmin MUST revert for any caller that is
    ///         not the current emergencyAdmin.
    function check_OnlyEmergencyAdminCanTransferAdmin(address caller, address newAdmin) public {
        address admin = boundary.emergencyAdmin();
        vm.assume(caller != admin);
        vm.assume(newAdmin != address(0));

        vm.prank(caller);
        (bool success, ) = address(boundary).call(
            abi.encodeWithSelector(
                boundary.setEmergencyAdmin.selector,
                newAdmin
            )
        );

        assertTrue(!success);
    }

    /// @notice SYMBOLIC: setStandardDebit MUST revert for any caller that is
    ///         not the allowlistAdmin.
    function check_OnlyAllowlistAdminCanSetStandardDebit(address caller) public {
        address admin = boundary.allowlistAdmin();
        vm.assume(caller != admin);

        vm.prank(caller);
        (bool success, ) = address(boundary).call(
            abi.encodeWithSelector(
                boundary.setStandardDebit.selector,
                address(mockAsset),
                true
            )
        );

        assertTrue(!success);
    }
}
