// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../../src/escrow/EscrowEngine.sol";

contract AdversarialChaosTest is Test {
    EscrowEngine public escrow;
    
    address public payer = address(0x101);
    address public payee = address(0x202);
    address public attacker = address(0x303);

    function setUp() public {
        escrow = new EscrowEngine();
        
        vm.deal(payer, 10 ether);
        vm.deal(payee, 10 ether);
        vm.deal(attacker, 10 ether);
    }

    /// @notice Simulates a high-congestion block where an attacker tries to double-spend or corrupt state
    function test_Chaos_ConcurrentEscrowState() public {
        uint256 amount = 1 ether;
        // The caller generates the ID prior to calling the engine
        bytes32 escrowId = keccak256("ai-task-001");
        
        // Payer creates the escrow
        vm.prank(payer);
        escrow.createEscrow{value: amount}(escrowId, payee);

        // VALID EXECUTION: The escrow is released
        vm.prank(payer);
        escrow.release(escrowId);

        // ATTEMPT 1: Attacker tries to back-run / double-spend the release in the exact same block
        vm.startPrank(attacker);
        vm.expectRevert(EscrowEngine.EscrowAlreadyReleased.selector); 
        escrow.release(escrowId);
        vm.stopPrank();

        // ATTEMPT 2: Attacker tries to refund an already released escrow (state collision)
        vm.startPrank(attacker);
        vm.expectRevert(EscrowEngine.EscrowAlreadyReleased.selector); 
        escrow.refund(escrowId);
        vm.stopPrank();
    }
}
