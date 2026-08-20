// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {AkmenaCore} from "../../../src/core/AkmenaCore.sol";
import {PrivacyEngine} from "../../../src/privacy/PrivacyEngine.sol";
import {EscrowEngine} from "../../../src/economics/EscrowEngine.sol";
import {AkmenaPolicyBoundary} from "../../../src/authorization/AkmenaPolicyBoundary.sol";

contract AgentBatcher {
    PrivacyEngine privacy;
    AkmenaPolicyBoundary boundary;
    
    constructor(PrivacyEngine _privacy, AkmenaPolicyBoundary _boundary) {
        privacy = _privacy;
        boundary = _boundary;
    }

    function batchExecute(bytes32 nullifierHash, bytes32 secret, uint256 amount, address target) external {
        privacy.executePrivateSettlement(nullifierHash, secret, amount, payable(address(this)));

        bytes memory payload = abi.encodeWithSignature("ping()");
        // Route exactly to PRIVACY_ENGINE using the transient receipt mapped to this batcher
        boundary.executeAgentCall(msg.sender, target, amount, bytes32("PRIVACY_ENGINE"), uint256(nullifierHash), payload);
    }
    
    receive() external payable {}
}

contract MockTarget {
    function ping() external pure returns (bool) { return true; }
}

contract Integration_TransientBoundaryTest is Test {
    AkmenaCore core;
    PrivacyEngine privacy;
    EscrowEngine escrow;
    AkmenaPolicyBoundary boundary;
    MockTarget target;
    AgentBatcher batcher;

    address agent = address(0xAAAA);

    function setUp() public {
        core = new AkmenaCore();
        privacy = new PrivacyEngine();
        escrow = new EscrowEngine();
        boundary = new AkmenaPolicyBoundary(address(core));
        target = new MockTarget();
        batcher = new AgentBatcher(privacy, boundary);

        core.registerModule(bytes32("PRIVACY_ENGINE"), address(privacy), "1.0.0");
        core.registerModule(bytes32("ESCROW_ENGINE"), address(escrow), "1.0.0");

        vm.prank(agent);
        boundary.setAgentPolicy(address(batcher), 100 ether, 1000 ether, true);
    }

    function test_ProofSuccessfullyPassesBoundary() public {
        bytes32 secret = keccak256("agent-secret");
        bytes32 nullifierHash = keccak256("workflow-002");
        uint256 amount = 5 ether;
        
        bytes32 commitment = keccak256(abi.encodePacked(nullifierHash, secret, amount));

        vm.deal(agent, 10 ether);
        vm.prank(agent);
        privacy.depositPrivateEscrow{value: amount}(commitment);

        vm.prank(agent);
        // This will now completely succeed because the dynamic routing verifies the TSTORE memory
        batcher.batchExecute(nullifierHash, secret, amount, address(target));
        
        console.log("Boundary Successfully Verified Cross-Contract Transient Proof!");
    }
}
