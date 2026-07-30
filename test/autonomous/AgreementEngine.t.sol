// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AgreementEngine} from "../../src/autonomous/AgreementEngine.sol";
import {IAgreementEngine} from "../../src/autonomous/IAgreementEngine.sol";
import {LibStorage} from "../../src/storage/LibStorage.sol";

contract AgreementEngineTest is Test {
    AgreementEngine public engine;
    address public partyA = address(0xAAA);
    address public partyB = address(0xBBB);
    bytes32 public agreementId = keccak256("AGREEMENT_001");
    bytes32 public termsHash = keccak256("TERMS_OF_SERVICE");

    function setUp() public {
        engine = new AgreementEngine();
    }

    function test_CreateAgreement() public {
        vm.prank(partyA);
        vm.expectEmit(true, true, true, true);
        emit IAgreementEngine.AgreementCreated(agreementId, partyA, partyB);

        engine.createAgreement(agreementId, partyB, termsHash, block.timestamp + 100);

        LibStorage.AgreementData memory data = engine.getAgreement(agreementId);
        assertEq(data.partyA, partyA);
        assertEq(data.partyB, partyB);
        assertEq(data.termsHash, termsHash);
        assertFalse(data.isExecuted);
    }

    function test_ExecuteAgreement() public {
        vm.prank(partyA);
        engine.createAgreement(agreementId, partyB, termsHash, block.timestamp + 100);

        vm.prank(partyB);
        vm.expectEmit(true, true, true, true);
        emit IAgreementEngine.AgreementExecuted(agreementId);

        engine.executeAgreement(agreementId);
        
        LibStorage.AgreementData memory data = engine.getAgreement(agreementId);
        assertTrue(data.isExecuted);
    }

    function test_RevertWhen_UnauthorizedExecution() public {
        vm.prank(partyA);
        engine.createAgreement(agreementId, partyB, termsHash, block.timestamp + 100);

        vm.prank(address(0xCCC));
        vm.expectRevert(IAgreementEngine.UnauthorizedAccess.selector);
        engine.executeAgreement(agreementId);
    }

    function test_RevertWhen_AgreementExpired() public {
        vm.prank(partyA);
        engine.createAgreement(agreementId, partyB, termsHash, block.timestamp + 10);

        vm.warp(block.timestamp + 20); // Fast forward time past expiration

        vm.prank(partyB);
        vm.expectRevert(IAgreementEngine.AgreementExpired.selector);
        engine.executeAgreement(agreementId);
    }
}
