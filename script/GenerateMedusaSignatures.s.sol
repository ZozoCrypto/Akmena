// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {ModelDBoundaryHandlerMedusa, MedusaFuzzAdapter} from "../test/invariant/handlers/ModelDBoundaryHandlerMedusa.sol";
import {AkmenaExecutionAuthorization} from "../src/authorization/AkmenaExecutionAuthorization.sol";

/// @notice Generates pre-signed intents for the Medusa handler.
/// @dev Workflow:
///      1. Start Anvil: `anvil`
///      2. Run: `forge script script/GenerateMedusaSignatures.s.sol --rpc-url http://localhost:8545 --broadcast --private-key <KEY>`
///      3. Dump state: `cast rpc anvil_dumpState --rpc-url http://localhost:8545 > medusa_genesis.json`
///      4. Configure medusa.json with genesisStateFile and genesisContractMappings
///      5. Run: `medusa fuzz`
///      Medusa loads the genesis state containing the deployed handler with
///      pre-signed intents already registered.
contract GenerateMedusaSignatures is Script {
    uint256 internal constant AGENT1_KEY = 0xA6E171;
    uint256 internal constant AGENT2_KEY = 0xA6E172;

    ModelDBoundaryHandlerMedusa internal handler;
    AkmenaExecutionAuthorization internal auth;

    function run() external {
        vm.startBroadcast();

        // Deploy the handler (deploys full stack in constructor).
        handler = new ModelDBoundaryHandlerMedusa();
        auth = handler.auth();

        console.log("Handler:", address(handler));
        console.log("Auth:", address(auth));

        // Generate 16 intents: 2 operators x 2 agents x 4 amounts.
        // Register one at a time to avoid stack-too-deep.
        uint256 idx = 0;
        idx = _genFor(handler.OPERATOR1(), handler.AGENT1(), AGENT1_KEY, idx);
        idx = _genFor(handler.OPERATOR1(), handler.AGENT2(), AGENT2_KEY, idx);
        idx = _genFor(handler.OPERATOR2(), handler.AGENT1(), AGENT1_KEY, idx);
        idx = _genFor(handler.OPERATOR2(), handler.AGENT2(), AGENT2_KEY, idx);

        console.log("Registered intents:", idx);
        console.log("NEXT: medusa target =", address(handler));
    }

    function _genFor(address operator, address agent, uint256 agentKey, uint256 startIdx)
        internal returns (uint256)
    {
        uint256 idx = startIdx;
        idx = _genOne(operator, agent, agentKey, 1 ether, idx);
        idx = _genOne(operator, agent, agentKey, 10 ether, idx);
        idx = _genOne(operator, agent, agentKey, 100 ether, idx);
        idx = _genOne(operator, agent, agentKey, 1000 ether, idx);
        return idx;
    }

    function _genOne(address operator, address agent, uint256 agentKey, uint256 amount, uint256 nonce)
        internal returns (uint256)
    {
        bytes memory payload = abi.encodeWithSelector(MedusaFuzzAdapter.execute.selector, amount);

        AkmenaExecutionAuthorization.ExecutionIntent memory intent =
            AkmenaExecutionAuthorization.ExecutionIntent({
                operator: operator,
                agent: agent,
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
                deadline: block.timestamp + 1 days
            });

        bytes32 digest = auth.hashIntent(intent);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(agentKey, digest);
        bytes memory sig = abi.encodePacked(r, s, v);

        // Register single intent.
        AkmenaExecutionAuthorization.ExecutionIntent[] memory intents =
            new AkmenaExecutionAuthorization.ExecutionIntent[](1);
        bytes[] memory payloads = new bytes[](1);
        bytes[] memory sigs = new bytes[](1);
        intents[0] = intent;
        payloads[0] = payload;
        sigs[0] = sig;
        handler.registerPresigned(intents, payloads, sigs);

        return nonce + 1;
    }
}
