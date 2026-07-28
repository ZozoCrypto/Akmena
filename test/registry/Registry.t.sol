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

    // Original working functions
    function identityId() external view override returns (uint256) { return _id; }
    function identityType() external view override returns (IdentityType) { return _type; }
    
    // Newly added functions to strictly satisfy IIdentity
    function isActive() external pure override returns (bool) { return true; }
    function metadataURI() external pure override returns (string memory) { return ""; }
    function owner() external view override returns (address) { return _owner; }
    function protocolVersion() external pure override returns (string memory) { return "1.0"; }
}

// ---------------------------------------------------------------------
// Registry Test Suite
// ---------------------------------------------------------------------
contract RegistryTest is Test {
    Registry public registry;

    event IdentityRegistered(uint256 indexed identityId, address indexed identity, IIdentity.IdentityType identityType);
    event IdentityRemoved(uint256 indexed identityId, address indexed identity);

    function setUp() public {
        registry = new Registry();
    }

    // =============================================================
    // Allocation Tests
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
    // Registration Tests
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
        MockIdentity mock2 = new MockIdentity(1, IIdentity.IdentityType.Organization); // Duplicate ID!

        registry.registerIdentity(address(mock1));

        vm.expectRevert(IRegistry.IdentityAlreadyRegistered.selector);
        registry.registerIdentity(address(mock2));
    }

    // =============================================================
    // Removal Tests
    // =============================================================

    function test_RemoveIdentity() public {
        MockIdentity mock = new MockIdentity(1, IIdentity.IdentityType.Human);
        registry.registerIdentity(address(mock));

        vm.expectEmit(true, true, true, true);
        emit IdentityRemoved(1, address(mock));

        registry.removeIdentity(1);

        assertFalse(registry.exists(1), "Identity should not exist after removal");
        assertEq(registry.identityAddress(1), address(0), "Address mapping should clear");
        assertEq(registry.identityId(address(mock)), 0, "ID mapping should clear");
    }

    function test_RevertWhen_RemovingNonExistentIdentity() public {
        vm.expectRevert(IRegistry.IdentityNotFound.selector);
        registry.removeIdentity(99);
    }
}
