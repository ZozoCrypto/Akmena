// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract AgentCapabilityFirewall is EIP712 {

    bytes32 public constant INTENT_TYPEHASH =
        keccak256(
            "AgentIntent(address agent,bytes32 capability,address target,bytes4 selector,uint256 amount,uint256 nonce)"
        );


    error CapabilityMismatch();
    error SelectorMismatch();
    error TargetMismatch();


    struct Intent {
        address agent;
        bytes32 capability;
        address target;
        bytes4 selector;
        uint256 amount;
        uint256 nonce;
    }


    bytes32 public immutable allowedCapability;
    address public immutable allowedTarget;
    bytes4 public immutable allowedSelector;


    constructor(
        bytes32 capability,
        address target,
        bytes4 selector
    )
        EIP712(
            "AkmenaCapabilityFirewall",
            "1"
        )
    {
        allowedCapability = capability;
        allowedTarget = target;
        allowedSelector = selector;
    }


    function validate(
        Intent calldata intent
    )
        external
        view
    {
        if(intent.capability != allowedCapability)
            revert CapabilityMismatch();

        if(intent.target != allowedTarget)
            revert TargetMismatch();

        if(intent.selector != allowedSelector)
            revert SelectorMismatch();
    }
}


contract Attack_AgentCapabilityFirewallTest is Test {

    bytes32 constant PAYMENT =
        keccak256("AKM_PAYMENT");

    bytes32 constant ESCROW =
        keccak256("AKM_ESCROW");


    address constant ROUTER =
        address(0x1111);

    address constant TOKEN =
        address(0x2222);


    AgentCapabilityFirewall firewall;


    function setUp()
        public
    {
        firewall =
            new AgentCapabilityFirewall(
                PAYMENT,
                ROUTER,
                bytes4(keccak256("pay(uint256)"))
            );
    }


    function test_AllowedCapabilityPasses()
        public
        view
    {
        firewall.validate(
            AgentCapabilityFirewall.Intent({
                agent: address(this),
                capability: PAYMENT,
                target: ROUTER,
                selector: bytes4(keccak256("pay(uint256)")),
                amount: 1 ether,
                nonce: 1
            })
        );
    }


    function test_CapabilitySubstitutionFails()
        public
    {
        vm.expectRevert(
            AgentCapabilityFirewall.CapabilityMismatch.selector
        );

        firewall.validate(
            AgentCapabilityFirewall.Intent({
                agent: address(this),
                capability: ESCROW,
                target: ROUTER,
                selector: bytes4(keccak256("pay(uint256)")),
                amount: 1 ether,
                nonce: 1
            })
        );
    }


    function test_TargetSubstitutionFails()
        public
    {
        vm.expectRevert(
            AgentCapabilityFirewall.TargetMismatch.selector
        );

        firewall.validate(
            AgentCapabilityFirewall.Intent({
                agent: address(this),
                capability: PAYMENT,
                target: TOKEN,
                selector: bytes4(keccak256("pay(uint256)")),
                amount: 1 ether,
                nonce: 1
            })
        );
    }


    function test_SelectorSubstitutionFails()
        public
    {
        vm.expectRevert(
            AgentCapabilityFirewall.SelectorMismatch.selector
        );

        firewall.validate(
            AgentCapabilityFirewall.Intent({
                agent: address(this),
                capability: PAYMENT,
                target: ROUTER,
                selector: bytes4(keccak256("approve(address,uint256)")),
                amount: 1 ether,
                nonce: 1
            })
        );
    }
}
