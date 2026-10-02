// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {ModelDBoundaryHandlerMedusa, MedusaFuzzAdapter} from "../test/invariant/handlers/ModelDBoundaryHandlerMedusa.sol";
import {AkmenaExecutionAuthorization} from "../src/authorization/AkmenaExecutionAuthorization.sol";

/// @notice Registers pre-signed intents on an already-deployed Medusa handler.
/// @dev Workaround for forge script broadcast bug (nested `new` deployments revert
///      on nightly builds). Workflow:
///      1. Deploy handler via `cast send --create <initcode>` (get initcode from artifact)
///      2. From OPERATOR keys: token.approve(boundary) + boundary.setAgentAssetPolicy(handler, token, ...)
///      3. Run: `forge script script/RegisterMedusaIntents.s.sol --sig "run(address)" <HANDLER>
///               --rpc-url http://localhost:8545 --broadcast --private-key <KEY>`
///      4. Dump state: `cast rpc anvil_dumpState --rpc-url http://localhost:8545 > medusa_genesis.json`
///
///      AGENT MODEL: the handler is its own intent agent (ERC-1271). Intents carry
///      intent.agent == handler address; the handler authorizes the digest at
///      registration time. Signatures are dummy bytes (test-harness only).
contract RegisterMedusaIntents is Script {
    function run(address handlerAddr) external {
        ModelDBoundaryHandlerMedusa handler = ModelDBoundaryHandlerMedusa(handlerAddr);

        // Collect all intents first: registerPresigned is one-shot.
        uint256 total = 8; // 2 operators x 4 amounts
        AkmenaExecutionAuthorization.ExecutionIntent[] memory intents =
            new AkmenaExecutionAuthorization.ExecutionIntent[](total);
        bytes[] memory payloads = new bytes[](total);
        bytes[] memory sigs = new bytes[](total);

        uint256 idx = 0;
        idx = _genFor(handler, handler.OPERATOR1(), idx, intents, payloads, sigs);
        idx = _genFor(handler, handler.OPERATOR2(), idx, intents, payloads, sigs);

        vm.startBroadcast();
        handler.registerPresigned(intents, payloads, sigs);
        vm.stopBroadcast();

        console.log("Registered intents:", idx);
        console.log("Handler:", handlerAddr);
        console.log("Agent (handler):", handlerAddr);
    }

    function _genFor(
        ModelDBoundaryHandlerMedusa handler,
        address operator,
        uint256 startIdx,
        AkmenaExecutionAuthorization.ExecutionIntent[] memory intents,
        bytes[] memory payloads,
        bytes[] memory sigs
    ) internal view returns (uint256) {
        uint256 idx = startIdx;
        (intents[idx], payloads[idx], sigs[idx]) = _genOne(handler, operator, 1 ether, idx); idx++;
        (intents[idx], payloads[idx], sigs[idx]) = _genOne(handler, operator, 10 ether, idx); idx++;
        (intents[idx], payloads[idx], sigs[idx]) = _genOne(handler, operator, 100 ether, idx); idx++;
        (intents[idx], payloads[idx], sigs[idx]) = _genOne(handler, operator, 1000 ether, idx); idx++;
        return idx;
    }

    function _genOne(
        ModelDBoundaryHandlerMedusa handler,
        address operator,
        uint256 amount,
        uint256 nonce
    )
        internal
        view
        returns (
            AkmenaExecutionAuthorization.ExecutionIntent memory intent,
            bytes memory payload,
            bytes memory sig
        )
    {
        payload = abi.encodeWithSelector(MedusaFuzzAdapter.execute.selector, amount);
        intent = _buildIntent(handler, operator, payload, amount, nonce);
        // Dummy signature: the handler authorizes by digest registry (ERC-1271),
        // not by ECDSA recovery. 65 zero bytes keep the calldata shape realistic.
        sig = new bytes(65);
    }

    function _buildIntent(
        ModelDBoundaryHandlerMedusa handler,
        address operator,
        bytes memory payload,
        uint256 amount,
        uint256 nonce
    ) internal view returns (AkmenaExecutionAuthorization.ExecutionIntent memory) {
        return AkmenaExecutionAuthorization.ExecutionIntent({
            operator: operator,
            agent: address(handler),
            target: address(handler.adapter()),
            selector: MedusaFuzzAdapter.execute.selector,
            calldataHash: keccak256(payload),
            asset: address(handler.token()),
            amount: amount,
            value: 0,
            proofModuleKey: bytes32(0),
            proofId: 0,
            nonce: nonce,
            validAfter: 0,
            deadline: block.timestamp + 30 days
        });
    }
}
