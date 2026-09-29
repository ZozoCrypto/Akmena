// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {AkmenaCore} from "../../../src/core/AkmenaCore.sol";
import {AkmenaPolicyBoundary} from "../../../src/authorization/AkmenaPolicyBoundary.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @notice Minimal mock token (has code, satisfies the contract check).
contract SelfAdapterToken is ERC20 {
    constructor() ERC20("SelfAdapter", "SAT") {}
}

/// @notice Minimal mock adapter (has code, satisfies the contract check).
contract SelfAdapterMock {
    function noop() external {}
}

/// @notice Regression tests for the self-adapter guard in setEconomicAdapter:
/// ENABLING a token as its own economic adapter must revert with
/// InvalidAdapter(), while REVOKING one stays permitted so a previously
/// granted self-adapter can always be removed. A token's adapter entrypoint
/// would execute with the token's full ledger control, letting it offset
/// outflows with mints that net-delta spending accounting cannot observe
/// (residual gross-outflow risk: net-zero and partial-credit flows via
/// colluding adapter/token pairs remain possible and are NOT fixed by this
/// guard).
contract Attack_SelfAdapterRejected is Test {
    AkmenaCore internal core;
    AkmenaPolicyBoundary internal boundary;
    SelfAdapterToken internal token;
    SelfAdapterMock internal adapter;

    function setUp() public {
        core = new AkmenaCore(); // test contract IS core.deployer()
        boundary = new AkmenaPolicyBoundary(address(core));
        token = new SelfAdapterToken();
        adapter = new SelfAdapterMock();
    }

    /// @notice Storage slot of economicAdapters[asset][adapter].
    /// @dev Layout: agentPolicies = slot 0, agentAssetPolicies = slot 1,
    ///      economicAdapters = slot 2 (immutables occupy no storage).
    function _allowlistSlot(address asset, address adpt) internal pure returns (bytes32) {
        bytes32 inner = keccak256(abi.encode(asset, uint256(2)));
        return keccak256(abi.encode(adpt, inner));
    }

    /// @notice 1. Enabling a token as its own adapter must revert and must
    /// not write the allowlist entry.
    function test_enableSelfAdapterReverts() public {
        vm.expectRevert(AkmenaPolicyBoundary.InvalidAdapter.selector);
        boundary.setEconomicAdapter(address(token), address(token), true);

        assertFalse(
            boundary.economicAdapters(address(token), address(token)),
            "self-adapter must not be allowlisted"
        );
    }

    /// @notice 2. Revoking a self-adapter is allowed: simulate a pre-existing
    /// grant (e.g. allowlisted before the guard) via vm.store, then prove
    /// setEconomicAdapter(token, token, false) clears it without reverting.
    function test_revokeSelfAdapterAllowed() public {
        bytes32 slot = _allowlistSlot(address(token), address(token));
        vm.store(address(boundary), slot, bytes32(uint256(1)));
        assertTrue(
            boundary.economicAdapters(address(token), address(token)),
            "pre-existing grant simulation failed"
        );

        boundary.setEconomicAdapter(address(token), address(token), false);

        assertFalse(
            boundary.economicAdapters(address(token), address(token)),
            "revocation did not clear the self-adapter"
        );
    }

    /// @notice 2b. Revoking a never-granted self-adapter pair is a harmless
    /// no-op (must not revert either).
    function test_revokeNonExistentSelfAdapterAllowed() public {
        boundary.setEconomicAdapter(address(token), address(token), false);

        assertFalse(
            boundary.economicAdapters(address(token), address(token)),
            "allowlist must stay empty"
        );
    }

    /// @notice 3. Control: a distinct adapter for the same asset can still be
    /// enabled and disabled normally (the guard must not break legitimate
    /// allowlist lifecycle).
    function test_distinctAdapterEnableDisable() public {
        boundary.setEconomicAdapter(address(token), address(adapter), true);
        assertTrue(
            boundary.economicAdapters(address(token), address(adapter)),
            "distinct adapter enable broken"
        );

        boundary.setEconomicAdapter(address(token), address(adapter), false);
        assertFalse(
            boundary.economicAdapters(address(token), address(adapter)),
            "distinct adapter revoke broken"
        );
    }
}
