// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC1363Receiver} from "../interfaces/IERC1363Receiver.sol";
import {IERC1363Spender} from "../interfaces/IERC1363Spender.sol";
import {AKMErrors} from "../lib/AKMErrors.sol";

abstract contract Akmena1363 {
    // Internal execution hooks mapped to the main contract
    function _executeTransfer(address from, address to, uint256 value) internal virtual;
    function _executeApprove(address owner, address spender, uint256 value) internal virtual;

    function transferAndCall(address to, uint256 value) public virtual returns (bool) {
        return transferAndCall(to, value, "");
    }

    function transferAndCall(address to, uint256 value, bytes memory data) public virtual returns (bool) {
        _executeTransfer(msg.sender, to, value);
        _checkOnTransferReceived(msg.sender, msg.sender, to, value, data);
        return true;
    }

    function transferFromAndCall(address from, address to, uint256 value) public virtual returns (bool) {
        return transferFromAndCall(from, to, value, "");
    }

    function transferFromAndCall(address from, address to, uint256 value, bytes memory data) public virtual returns (bool) {
        _executeTransfer(from, to, value);
        _checkOnTransferReceived(msg.sender, from, to, value, data);
        return true;
    }

    function approveAndCall(address spender, uint256 value) public virtual returns (bool) {
        return approveAndCall(spender, value, "");
    }

    function approveAndCall(address spender, uint256 value, bytes memory data) public virtual returns (bool) {
        _executeApprove(msg.sender, spender, value);
        if (spender.code.length == 0) revert AKMErrors.TransferToNonContract();
        try IERC1363Spender(spender).onApprovalReceived(msg.sender, value, data) returns (bytes4 retval) {
            if (retval != IERC1363Spender.onApprovalReceived.selector) revert AKMErrors.SpenderRejected();
        } catch {
            revert AKMErrors.SpenderRejected();
        }
        return true;
    }

    function _checkOnTransferReceived(address operator, address from, address to, uint256 value, bytes memory data) private {
        if (to.code.length == 0) revert AKMErrors.TransferToNonContract();
        try IERC1363Receiver(to).onTransferReceived(operator, from, value, data) returns (bytes4 retval) {
            if (retval != IERC1363Receiver.onTransferReceived.selector) revert AKMErrors.ReceiverRejected();
        } catch {
            revert AKMErrors.ReceiverRejected();
        }
    }
}