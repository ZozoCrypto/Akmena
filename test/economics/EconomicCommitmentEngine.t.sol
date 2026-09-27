// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {AgreementEngine} from "../../src/autonomous/AgreementEngine.sol";
import {EscrowEngine} from "../../src/economics/EscrowEngine.sol";
import {EconomicCommitmentEngine} from "../../src/economics/EconomicCommitmentEngine.sol";

import {IEconomicCommitmentEngine} from "../../src/economics/IEconomicCommitmentEngine.sol";

contract EconomicTestToken is ERC20 {
    constructor() ERC20("Economic Test AKM", "eAKM") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract EconomicCommitmentEngineTest is Test {
    EconomicTestToken internal token;
    AgreementEngine internal agreement;
    EscrowEngine internal escrow;
    EconomicCommitmentEngine internal economic;

    address internal buyer = address(0xB001);
    address internal seller = address(0xB002);
    address internal buyer2 = address(0xB003);
    address internal seller2 = address(0xB004);
    address internal attacker = address(0xBAD);

    uint256 internal constant AMOUNT = 100 ether;

    bytes32 internal constant AGREEMENT_ID = keccak256("AKMENA-ECONOMIC-AGREEMENT-1");

    function setUp() public {
        token = new EconomicTestToken();
        agreement = new AgreementEngine();
        escrow = new EscrowEngine(address(token));
        economic = new EconomicCommitmentEngine(address(agreement), address(escrow));

        token.mint(buyer, 1_000 ether);
        token.mint(buyer2, 1_000 ether);

        vm.prank(buyer);
        token.approve(address(escrow), type(uint256).max);

        vm.prank(buyer2);
        token.approve(address(escrow), type(uint256).max);
    }

    function _createExecutedAgreement(
        bytes32 agreementId,
        address partyA,
        address partyB,
        address asset,
        uint256 amount
    ) internal {
        bytes32 termsHash = economic.computeEconomicTermsHash(partyA, partyB, asset, amount);

        vm.prank(partyA);
        agreement.createAgreement(agreementId, partyB, termsHash, type(uint256).max);

        vm.prank(partyB);
        agreement.executeAgreement(agreementId);
    }

    function _createCommitment() internal returns (bytes32 commitmentId) {
        _createExecutedAgreement(AGREEMENT_ID, buyer, seller, address(token), AMOUNT);

        vm.prank(buyer);
        commitmentId = economic.createCommitment(AGREEMENT_ID, address(token), AMOUNT);
    }

    // =========================================================
    // 1. COMPLETE ECONOMIC PATH
    // =========================================================

    function test_CompleteEconomicLifecycle() public {
        bytes32 commitmentId = _createCommitment();

        vm.prank(buyer);
        uint256 escrowId = escrow.createEscrow(buyer, seller, AMOUNT, commitmentId);

        vm.prank(buyer);
        economic.attachEscrow(commitmentId, escrowId);

        IEconomicCommitmentEngine.EconomicCommitment memory committed = economic.getCommitment(commitmentId);

        assertEq(committed.agreementId, AGREEMENT_ID);
        assertEq(committed.escrowId, escrowId);
        assertEq(committed.payer, buyer);
        assertEq(committed.payee, seller);
        assertEq(committed.asset, address(token));
        assertEq(committed.amount, AMOUNT);
        assertEq(uint8(committed.status), uint8(IEconomicCommitmentEngine.CommitmentStatus.EscrowAttached));

        assertEq(token.balanceOf(address(escrow)), AMOUNT);

        vm.prank(buyer);
        escrow.releaseEscrow(escrowId);

        assertEq(token.balanceOf(seller), AMOUNT);

        economic.finalizeSettlement(escrowId, commitmentId);

        IEconomicCommitmentEngine.EconomicCommitment memory settled = economic.getCommitment(commitmentId);

        assertEq(uint8(settled.status), uint8(IEconomicCommitmentEngine.CommitmentStatus.Settled));

        IEconomicCommitmentEngine.EconomicSettlement memory settlement = economic.getSettlement(commitmentId);

        assertEq(settlement.commitmentId, commitmentId);
        assertEq(settlement.agreementId, AGREEMENT_ID);
        assertEq(settlement.escrowId, escrowId);
        assertEq(settlement.payer, buyer);
        assertEq(settlement.payee, seller);
        assertEq(settlement.asset, address(token));
        assertEq(settlement.amount, AMOUNT);
        assertGt(settlement.timestamp, 0);
    }

    // =========================================================
    // 2. WRONG ESCROW
    // =========================================================

    function test_WrongEscrowRejected() public {
        bytes32 commitmentId = _createCommitment();

        bytes32 otherReference = keccak256("other-reference");

        vm.prank(buyer);
        escrow.createEscrow(buyer, seller, AMOUNT, otherReference);

        vm.prank(buyer);
        vm.expectRevert(IEconomicCommitmentEngine.EscrowCommitmentMismatch.selector);
        economic.attachEscrow(commitmentId, 1);
    }

    // =========================================================
    // 3. WRONG AMOUNT
    // =========================================================

    function test_WrongAmountRejected() public {
        bytes32 commitmentId = _createCommitment();

        vm.prank(buyer);
        escrow.createEscrow(buyer, seller, AMOUNT + 1 ether, commitmentId);

        vm.prank(buyer);
        vm.expectRevert(IEconomicCommitmentEngine.EscrowStateMismatch.selector);
        economic.attachEscrow(commitmentId, 1);
    }

    // =========================================================
    // 4. WRONG PAYER
    // =========================================================

    function test_WrongPayerRejected() public {
        bytes32 commitmentId = _createCommitment();

        vm.prank(buyer2);
        escrow.createEscrow(buyer2, seller, AMOUNT, commitmentId);

        vm.prank(buyer);
        vm.expectRevert(IEconomicCommitmentEngine.EscrowStateMismatch.selector);
        economic.attachEscrow(commitmentId, 1);
    }

    // =========================================================
    // 5. WRONG PAYEE
    // =========================================================

    function test_WrongPayeeRejected() public {
        bytes32 commitmentId = _createCommitment();

        vm.prank(buyer);
        escrow.createEscrow(buyer, seller2, AMOUNT, commitmentId);

        vm.prank(buyer);
        vm.expectRevert(IEconomicCommitmentEngine.EscrowStateMismatch.selector);
        economic.attachEscrow(commitmentId, 1);
    }

    // =========================================================
    // 6. WRONG ASSET
    // =========================================================

    function test_WrongAssetRejected() public {
        EconomicTestToken otherToken = new EconomicTestToken();

        bytes32 otherAgreementId = keccak256("agreement-wrong-asset");

        bytes32 commitmentTerms = economic.computeEconomicTermsHash(buyer, seller, address(otherToken), AMOUNT);

        vm.prank(buyer);
        agreement.createAgreement(otherAgreementId, seller, commitmentTerms, type(uint256).max);

        vm.prank(seller);
        agreement.executeAgreement(otherAgreementId);

        vm.prank(buyer);
        bytes32 commitmentId = economic.createCommitment(otherAgreementId, address(otherToken), AMOUNT);

        // The real EscrowEngine only custodies its immutable AKM asset.
        vm.prank(buyer);
        escrow.createEscrow(buyer, seller, AMOUNT, commitmentId);

        vm.prank(buyer);
        vm.expectRevert(IEconomicCommitmentEngine.EscrowStateMismatch.selector);
        economic.attachEscrow(commitmentId, 1);
    }

    // =========================================================
    // 7. WRONG ESCROW DURING FINALIZATION
    // =========================================================

    function test_FinalizeWrongEscrowRejected() public {
        bytes32 commitmentId = _createCommitment();

        vm.prank(buyer);
        uint256 escrowId = escrow.createEscrow(buyer, seller, AMOUNT, commitmentId);

        vm.prank(buyer);
        economic.attachEscrow(commitmentId, escrowId);

        uint256 wrongEscrowId = escrowId + 1;

        vm.expectRevert(IEconomicCommitmentEngine.EscrowCommitmentMismatch.selector);

        economic.finalizeSettlement(wrongEscrowId, commitmentId);

        IEconomicCommitmentEngine.EconomicCommitment memory state = economic.getCommitment(commitmentId);

        assertEq(state.escrowId, escrowId);
        assertEq(uint8(state.status), uint8(IEconomicCommitmentEngine.CommitmentStatus.EscrowAttached));
    }

    // =========================================================
    // 8. SETTLEMENT BEFORE VALUE MOVEMENT
    // =========================================================

    function test_SettlementBeforeReleaseRejected() public {
        bytes32 commitmentId = _createCommitment();

        vm.prank(buyer);
        uint256 escrowId = escrow.createEscrow(buyer, seller, AMOUNT, commitmentId);

        vm.prank(buyer);
        economic.attachEscrow(commitmentId, escrowId);

        vm.expectRevert(IEconomicCommitmentEngine.SettlementNotReleased.selector);

        economic.finalizeSettlement(escrowId, commitmentId);

        IEconomicCommitmentEngine.EconomicCommitment memory state = economic.getCommitment(commitmentId);

        assertEq(uint8(state.status), uint8(IEconomicCommitmentEngine.CommitmentStatus.EscrowAttached));
    }

    // =========================================================
    // 9. RELEASED BEFORE ATTACH
    // =========================================================

    function test_ReleasedBeforeAttachRejected() public {
        bytes32 commitmentId = _createCommitment();

        vm.prank(buyer);
        uint256 escrowId = escrow.createEscrow(buyer, seller, AMOUNT, commitmentId);

        vm.prank(buyer);
        escrow.releaseEscrow(escrowId);

        vm.prank(buyer);
        vm.expectRevert(IEconomicCommitmentEngine.EscrowStateMismatch.selector);
        economic.attachEscrow(commitmentId, escrowId);
    }

    // =========================================================
    // 10. REFUNDED BEFORE ATTACH
    // =========================================================

    function test_RefundedBeforeAttachRejected() public {
        bytes32 commitmentId = _createCommitment();

        vm.prank(buyer);
        uint256 escrowId = escrow.createEscrow(buyer, seller, AMOUNT, commitmentId);

        vm.prank(seller);
        escrow.refundEscrow(escrowId);

        vm.prank(buyer);
        vm.expectRevert(IEconomicCommitmentEngine.EscrowStateMismatch.selector);
        economic.attachEscrow(commitmentId, escrowId);
    }

    // =========================================================
    // 11. FABRICATED COMMITMENT
    // =========================================================

    function test_FabricatedSettlementRejected() public {
        bytes32 fakeCommitment = keccak256("fabricated-commitment");

        vm.expectRevert(IEconomicCommitmentEngine.CommitmentNotFound.selector);

        economic.finalizeSettlement(1, fakeCommitment);
    }

    // =========================================================
    // 12. DUPLICATE ESCROW REFERENCE
    // =========================================================

    function test_DuplicateEscrowReferenceRejected() public {
        bytes32 commitmentId = _createCommitment();

        vm.prank(buyer);
        escrow.createEscrow(buyer, seller, AMOUNT, commitmentId);

        vm.prank(buyer);
        vm.expectRevert(IEscrowEngineEscrowReferenceAlreadyUsed());
        escrow.createEscrow(buyer, seller, AMOUNT, commitmentId);
    }

    // =========================================================
    // 14. UNEXECUTED AGREEMENT CANNOT CREATE COMMITMENT
    // =========================================================

    function test_UnexecutedAgreementRejected() public {
        bytes32 agreementId = keccak256("unexecuted-agreement");

        bytes32 termsHash = economic.computeEconomicTermsHash(buyer, seller, address(token), AMOUNT);

        vm.prank(buyer);
        agreement.createAgreement(agreementId, seller, termsHash, type(uint256).max);

        vm.prank(buyer);
        vm.expectRevert(IEconomicCommitmentEngine.AgreementNotExecuted.selector);

        economic.createCommitment(agreementId, address(token), AMOUNT);
    }

    // =========================================================
    // Helper for interface error selector without importing
    // the error-bearing interface namespace twice.
    // =========================================================

    function IEscrowEngineEscrowReferenceAlreadyUsed() internal pure returns (bytes memory) {
        return abi.encodeWithSelector(bytes4(keccak256("EscrowReferenceAlreadyUsed()")));
    }
}
