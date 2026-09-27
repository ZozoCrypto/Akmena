// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {Registry} from "../../src/registry/Registry.sol";
import {IRegistry} from "../../src/registry/IRegistry.sol";
import {IIdentity} from "../../src/identity/IIdentity.sol";

// ---------------------------------------------------------------------
// Mock Identity
// ---------------------------------------------------------------------

contract MockIdentity is IIdentity {
    uint256 private _id;
    IdentityType private _type;
    address private _owner;

    constructor(uint256 id_, IdentityType type_) {
        _id = id_;
        _type = type_;
        _owner = msg.sender;
    }

    function identityId() external view override returns (uint256) {
        return _id;
    }

    function identityType() external view override returns (IdentityType) {
        return _type;
    }

    function isActive() external pure override returns (bool) {
        return true;
    }

    function metadataURI() external pure override returns (string memory) {
        return "";
    }

    function owner() external view override returns (address) {
        return _owner;
    }

    function protocolVersion() external pure override returns (string memory) {
        return "1.0";
    }
}

// ---------------------------------------------------------------------
// Mock Factory
// ---------------------------------------------------------------------

contract MockFactory {}

// ---------------------------------------------------------------------
// Registry Test Suite
// ---------------------------------------------------------------------

contract RegistryTest is Test {
    Registry public registry;

    event IdentityRegistered(uint256 indexed identityId, address indexed identity, IIdentity.IdentityType identityType);

    function setUp() public {
        registry = new Registry();
        registry.bindIdentityFactory(address(this));
    }

    // =============================================================
    // Bootstrap / Authority
    // =============================================================

    function test_BoundFactoryIsRecorded() public view {
        assertEq(registry.identityFactory(), address(this));
    }

    function test_RevertWhen_SecondFactoryBindingAttempted() public {
        MockFactory secondFactory = new MockFactory();

        vm.expectRevert(IRegistry.FactoryAlreadyBound.selector);
        registry.bindIdentityFactory(address(secondFactory));
    }

    function test_RevertWhen_UnauthorizedCallerAllocates() public {
        address attacker = address(0xBAD);

        vm.prank(attacker);
        vm.expectRevert(Registry.UnauthorizedFactory.selector);
        registry.allocateIdentityId();
    }

    function test_RevertWhen_UnauthorizedCallerRegisters() public {
        MockIdentity mock = new MockIdentity(1, IIdentity.IdentityType.Human);

        address attacker = address(0xBAD);

        vm.prank(attacker);
        vm.expectRevert(Registry.UnauthorizedFactory.selector);
        registry.registerIdentity(address(mock));
    }

    function test_RevertWhen_UnauthorizedCallerBindsFactory() public {
        Registry fresh = new Registry();
        MockFactory attackerFactory = new MockFactory();

        vm.prank(address(0xBAD));
        vm.expectRevert(IRegistry.UnauthorizedBinder.selector);
        fresh.bindIdentityFactory(address(attackerFactory));

        assertEq(fresh.identityFactory(), address(0));
    }

    function test_RevertWhen_BindingZeroFactory() public {
        Registry fresh = new Registry();

        vm.expectRevert(IRegistry.InvalidFactory.selector);
        fresh.bindIdentityFactory(address(0));

        assertEq(fresh.identityFactory(), address(0));
    }

    function test_RevertWhen_BindingEOAFactory() public {
        Registry fresh = new Registry();

        vm.expectRevert(IRegistry.InvalidFactory.selector);
        fresh.bindIdentityFactory(address(0xBEEF));

        assertEq(fresh.identityFactory(), address(0));
    }

    // =============================================================
    // Allocation
    // =============================================================

    function test_InitialNextIdentityId() public view {
        assertEq(registry.nextIdentityId(), 1, "Initial ID should start at 1");
    }

    function test_AllocateIdentityId() public {
        uint256 id1 = registry.allocateIdentityId();

        assertEq(id1, 1, "First allocated ID should be 1");
        assertEq(registry.nextIdentityId(), 2, "Next ID should increment to 2");

        uint256 id2 = registry.allocateIdentityId();

        assertEq(id2, 2, "Second allocated ID should be 2");
        assertEq(registry.nextIdentityId(), 3, "Next ID should increment to 3");
    }

    // =============================================================
    // Registration
    // =============================================================

    function test_RegisterIdentity() public {
        MockIdentity mock = new MockIdentity(1, IIdentity.IdentityType.Machine);

        vm.expectEmit(true, true, true, true);
        emit IdentityRegistered(1, address(mock), IIdentity.IdentityType.Machine);

        registry.registerIdentity(address(mock));

        assertTrue(registry.exists(1), "Identity should exist");
        assertEq(registry.identityAddress(1), address(mock), "Address mapping failed");
        assertEq(registry.identityId(address(mock)), 1, "ID mapping failed");
    }

    function test_RevertWhen_RegisteringDuplicateAddress() public {
        MockIdentity mock = new MockIdentity(1, IIdentity.IdentityType.Human);

        registry.registerIdentity(address(mock));

        vm.expectRevert(IRegistry.IdentityAlreadyRegistered.selector);
        registry.registerIdentity(address(mock));
    }

    function test_RevertWhen_RegisteringDuplicateId() public {
        MockIdentity mock1 = new MockIdentity(1, IIdentity.IdentityType.Organization);

        MockIdentity mock2 = new MockIdentity(1, IIdentity.IdentityType.Organization);

        registry.registerIdentity(address(mock1));

        vm.expectRevert(IRegistry.IdentityAlreadyRegistered.selector);
        registry.registerIdentity(address(mock2));
    }

    function test_RevertWhen_RegisteringZeroIdentity() public {
        vm.expectRevert(IRegistry.InvalidIdentity.selector);
        registry.registerIdentity(address(0));
    }

    function test_RevertWhen_RegisteringNonContractIdentity() public {
        address nonContract = address(0x123456);

        vm.expectRevert(IRegistry.InvalidIdentity.selector);
        registry.registerIdentity(nonContract);
    }

    function test_RevertWhen_RegisteringZeroIdentityId() public {
        MockIdentity mock = new MockIdentity(0, IIdentity.IdentityType.Human);

        vm.expectRevert(Registry.InvalidIdentityId.selector);
        registry.registerIdentity(address(mock));
    }

    // =============================================================
    // Permanent Historical Resolution
    // =============================================================

    function test_HistoricalIdentityResolutionIsPermanent() public {
        MockIdentity mock = new MockIdentity(1, IIdentity.IdentityType.Human);

        registry.registerIdentity(address(mock));

        assertTrue(registry.exists(1));
        assertEq(registry.identityAddress(1), address(mock));
        assertEq(registry.identityId(address(mock)), 1);

        // Registry has no destructive removal operation.
        assertTrue(registry.exists(1));
        assertEq(registry.identityAddress(1), address(mock));
        assertEq(registry.identityId(address(mock)), 1);
    }
}
