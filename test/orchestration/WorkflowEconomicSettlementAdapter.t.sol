// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {AkmenaCore} from "../../src/core/AkmenaCore.sol";
import {AkmenaToken} from "../../src/token/core/AkmenaToken.sol";

import {AgreementEngine} from "../../src/autonomous/AgreementEngine.sol";
import {EconomicCommitmentEngine} from "../../src/economics/EconomicCommitmentEngine.sol";
import {EscrowEngine} from "../../src/economics/EscrowEngine.sol";
import {IEconomicCommitmentEngine} from "../../src/economics/IEconomicCommitmentEngine.sol";

import {WorkflowEngine} from "../../src/orchestration/WorkflowEngine.sol";
import {ProtocolContext} from "../../src/orchestration/IWorkflowEngine.sol";

import {
    WorkflowEconomicSettlementAdapter
} from "../../src/orchestration/adapters/WorkflowEconomicSettlementAdapter.sol";

import {CapabilityEngine} from "../../src/authorization/CapabilityEngine.sol";
import {DelegationEngine} from "../../src/authorization/DelegationEngine.sol";
import {AuthorizationResolver} from "../../src/authorization/AuthorizationResolver.sol";
import {Registry} from "../../src/registry/Registry.sol";

contract WorkflowEconomicSettlementAdapterTest is Test {
    uint256 internal constant AMOUNT = 100 ether;

    address internal buyer = address(0x111);
    address internal seller = address(0x222);
    address internal attacker = address(0xBAD);

    bytes32 internal constant AGREEMENT_ID = keccak256("BLOCK24-AGREEMENT");

    AkmenaCore internal core;
    AkmenaToken internal token;
    AgreementEngine internal agreement;
    EscrowEngine internal escrow;
    EconomicCommitmentEngine internal economic;

    Registry internal registry;
    CapabilityEngine internal capabilityEngine;
    DelegationEngine internal delegation;
    AuthorizationResolver internal authorizationResolver;
    WorkflowEngine internal workflow;

    WorkflowEconomicSettlementAdapter internal adapter;

    uint256 internal validEscrowId;
    bytes32 internal validCommitmentId;

    function setUp() public {
        // -------------------------------------------------------------
        // Real production contracts
        // -------------------------------------------------------------

        core = new AkmenaCore();

        // The test contract receives the fixed initial AKM supply.
        token = new AkmenaToken(address(this));

        agreement = new AgreementEngine();
        escrow = new EscrowEngine(address(token));
        economic = new EconomicCommitmentEngine(address(agreement), address(escrow));

        // Real Workflow dependency chain.
        registry = new Registry();
        capabilityEngine = new CapabilityEngine();
        delegation = new DelegationEngine();

        authorizationResolver =
            new AuthorizationResolver(address(registry), address(capabilityEngine), address(delegation));

        workflow = new WorkflowEngine(address(core), address(authorizationResolver));

        // Actual production settlement boundary.
        adapter = new WorkflowEconomicSettlementAdapter(address(workflow), address(economic));

        // -------------------------------------------------------------
        // Build a real released economic commitment
        // -------------------------------------------------------------

        require(token.transfer(buyer, AMOUNT));

        bytes32 economicTermsHash = economic.computeEconomicTermsHash(buyer, seller, address(token), AMOUNT);

        vm.prank(buyer);
        agreement.createAgreement(AGREEMENT_ID, seller, economicTermsHash, block.timestamp + 1 days);

        // AgreementEngine requires partyB to execute.
        vm.prank(seller);
        agreement.executeAgreement(AGREEMENT_ID);

        // Buyer creates the economic commitment.
        vm.prank(buyer);
        validCommitmentId = economic.createCommitment(AGREEMENT_ID, address(token), AMOUNT);

        // Buyer funds the real escrow and attaches it.
        vm.startPrank(buyer);

        token.approve(address(escrow), AMOUNT);

        validEscrowId = escrow.createEscrow(buyer, seller, AMOUNT, validCommitmentId);

        economic.attachEscrow(validCommitmentId, validEscrowId);

        vm.stopPrank();

        // Buyer releases the real escrow.
        vm.prank(buyer);
        escrow.releaseEscrow(validEscrowId);
    }

    // =================================================================
    // 1. SUCCESSFUL SETTLEMENT THROUGH PRODUCTION ADAPTER
    // =================================================================

    function test_ExecuteSettlement_Success() public {
        bytes memory data = abi.encode(validCommitmentId);

        vm.prank(address(workflow));

        adapter.executeSettlement(
            bytes32(validEscrowId), data, ProtocolContext({actor: buyer, workflowId: keccak256("block24-workflow")})
        );

        IEconomicCommitmentEngine.EconomicCommitment memory commitment = economic.getCommitment(validCommitmentId);

        assertEq(uint8(commitment.status), uint8(IEconomicCommitmentEngine.CommitmentStatus.Settled));

        IEconomicCommitmentEngine.EconomicSettlement memory settlement = economic.getSettlement(validCommitmentId);

        assertEq(settlement.commitmentId, validCommitmentId);
        assertEq(settlement.escrowId, validEscrowId);
        assertEq(settlement.agreementId, AGREEMENT_ID);
        assertEq(settlement.payer, buyer);
        assertEq(settlement.payee, seller);
        assertEq(settlement.asset, address(token));
        assertEq(settlement.amount, AMOUNT);
        assertGt(settlement.timestamp, 0);
    }

    // =================================================================
    // 2. DIRECT ATTACKER CALL MUST FAIL AT ADAPTER BOUNDARY
    // =================================================================

    function test_Revert_ExecuteSettlement_InvalidCaller() public {
        bytes memory data = abi.encode(validCommitmentId);

        vm.prank(attacker);

        vm.expectRevert(WorkflowEconomicSettlementAdapter.InvalidWorkflowCaller.selector);

        adapter.executeSettlement(
            bytes32(validEscrowId), data, ProtocolContext({actor: attacker, workflowId: keccak256("attacker-workflow")})
        );
    }

    // =================================================================
    // 3. MALFORMED SETTLEMENT DATA
    // =================================================================

    function test_Revert_ExecuteSettlement_InvalidData() public {
        bytes memory malformedData = hex"1234";

        vm.prank(address(workflow));

        vm.expectRevert(WorkflowEconomicSettlementAdapter.InvalidSettlementData.selector);

        adapter.executeSettlement(
            bytes32(validEscrowId),
            malformedData,
            ProtocolContext({actor: buyer, workflowId: keccak256("malformed-workflow")})
        );
    }

    // =================================================================
    // 4. WRONG ESCROW ID MUST FAIL IN ECONOMIC PRIMITIVE
    // =================================================================

    function test_Revert_ExecuteSettlement_EscrowMismatch() public {
        bytes memory data = abi.encode(validCommitmentId);

        uint256 wrongEscrowId = validEscrowId + 999;

        vm.prank(address(workflow));

        vm.expectRevert(IEconomicCommitmentEngine.EscrowCommitmentMismatch.selector);

        adapter.executeSettlement(
            bytes32(wrongEscrowId),
            data,
            ProtocolContext({actor: buyer, workflowId: keccak256("wrong-escrow-workflow")})
        );
    }

    // =================================================================
    // 5. UNKNOWN COMMITMENT MUST FAIL IN ECONOMIC PRIMITIVE
    // =================================================================

    function test_Revert_ExecuteSettlement_CommitmentNotFound() public {
        bytes32 wrongCommitmentId = keccak256("wrong-commitment");

        bytes memory data = abi.encode(wrongCommitmentId);

        vm.prank(address(workflow));

        vm.expectRevert(IEconomicCommitmentEngine.CommitmentNotFound.selector);

        adapter.executeSettlement(
            bytes32(validEscrowId),
            data,
            ProtocolContext({actor: buyer, workflowId: keccak256("wrong-commitment-workflow")})
        );
    }

    // =================================================================
    // 6. REPEATED SETTLEMENT MUST BE IDEMPOTENT
    // =================================================================

    function test_ExecuteSettlement_Idempotent() public {
        bytes memory data = abi.encode(validCommitmentId);

        vm.startPrank(address(workflow));

        adapter.executeSettlement(
            bytes32(validEscrowId), data, ProtocolContext({actor: buyer, workflowId: keccak256("idempotent-workflow")})
        );

        IEconomicCommitmentEngine.EconomicSettlement memory first = economic.getSettlement(validCommitmentId);

        adapter.executeSettlement(
            bytes32(validEscrowId),
            data,
            ProtocolContext({actor: buyer, workflowId: keccak256("idempotent-workflow-replay")})
        );

        IEconomicCommitmentEngine.EconomicSettlement memory second = economic.getSettlement(validCommitmentId);

        vm.stopPrank();

        assertEq(first.settlementId, second.settlementId);
        assertEq(first.commitmentId, second.commitmentId);
        assertEq(first.escrowId, second.escrowId);
        assertEq(first.amount, second.amount);

        IEconomicCommitmentEngine.EconomicCommitment memory commitment = economic.getCommitment(validCommitmentId);

        assertEq(uint8(commitment.status), uint8(IEconomicCommitmentEngine.CommitmentStatus.Settled));
    }
}
