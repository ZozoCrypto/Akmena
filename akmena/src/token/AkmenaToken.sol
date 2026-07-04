// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {AkmenaAuthorization} from "./extensions/AkmenaAuthorization.sol";
import {Akmena1363} from "./extensions/Akmena1363.sol";
import {IAkmenaToken} from "./interfaces/IAkmenaToken.sol";
import {AKMErrors} from "./lib/AKMErrors.sol";

/// @title AkmenaToken (AKM)
/// @author Akmena Protocol
/// @notice The immutable financial kernel for the Akmena Protocol.
contract AkmenaToken is 
    ERC20, 
    ERC20Permit, 
    Ownable2Step, 
    AkmenaAuthorization, 
    Akmena1363, 
    IAkmenaToken 
{
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 1e18;

    constructor(address treasury) 
        ERC20("Akmena", "AKM") 
        ERC20Permit("Akmena") 
        Ownable(msg.sender) 
    {
        if (treasury == address(0)) revert AKMErrors.ZeroAddress();
        _mint(treasury, MAX_SUPPLY);
    }

    // ═════════════════════════════════════════════════════════════════════
    // Abstract Hooks Implementations
    // ═════════════════════════════════════════════════════════════════════
    
    function _domainHash(bytes32 structHash) internal view override returns (bytes32) {
        return _hashTypedDataV4(structHash);
    }

    function _settleAuthorizedTransfer(address from, address to, uint256 value) internal override {
        _transfer(from, to, value);
    }

    function _executeTransfer(address from, address to, uint256 value) internal override {
        // If transferFromAndCall is used, we must properly deduct the allowance
        if (from != msg.sender) {
            _spendAllowance(from, msg.sender, value);
        }
        _transfer(from, to, value);
    }

    function _executeApprove(address owner, address spender, uint256 value) internal override {
        _approve(owner, spender, value);
    }

    // ═════════════════════════════════════════════════════════════════════
    // Interface Conflict Resolution (The Override Matrix)
    // ═════════════════════════════════════════════════════════════════════

    function transferWithAuthorization(
        address from, address to, uint256 value, uint256 validAfter, uint256 validBefore, bytes32 nonce, uint8 v, bytes32 r, bytes32 s
    ) public override(AkmenaAuthorization, IAkmenaToken) {
        super.transferWithAuthorization(from, to, value, validAfter, validBefore, nonce, v, r, s);
    }

    function transferAndCall(address to, uint256 value) public override(Akmena1363, IAkmenaToken) returns (bool) {
        return super.transferAndCall(to, value);
    }

    function transferAndCall(address to, uint256 value, bytes memory data) public override(Akmena1363, IAkmenaToken) returns (bool) {
        return super.transferAndCall(to, value, data);
    }

    // ═════════════════════════════════════════════════════════════════════
    // Governance
    // ═════════════════════════════════════════════════════════════════════
    
    function renounceOwnership() public pure override {
        revert AKMErrors.Unauthorized();
    }
}