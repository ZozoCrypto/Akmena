// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {PrivacyEngine} from "../../../src/privacy/PrivacyEngine.sol";

contract PrivacyHandler is Test {
    PrivacyEngine public privacy;
    uint256 public expectedTotalBalance;

    constructor(PrivacyEngine _privacy) {
        privacy = _privacy;
    }

    function deposit(uint256 amount, uint256 seed) public {
        amount = bound(amount, 1, 100 ether);
        bytes32 commitment = keccak256(abi.encodePacked("commitment", seed));
        
        if (privacy.commitments(commitment)) return;

        vm.deal(address(this), amount);
        privacy.depositPrivateEscrow{value: amount}(commitment);
        expectedTotalBalance += amount;
    }

    receive() external payable {}
}

contract PrivacyEngineInvariantTest is Test {
    PrivacyEngine privacy;
    PrivacyHandler handler;

    function setUp() public {
        privacy = new PrivacyEngine();
        handler = new PrivacyHandler(privacy);
        targetContract(address(handler));
    }

    // Fixed: Added 'view' modifier
    function invariant_BalanceMatchesExpectedTotal() public view {
        assertEq(address(privacy).balance, handler.expectedTotalBalance(), "Privacy Engine balance invariant breached!");
    }
}
