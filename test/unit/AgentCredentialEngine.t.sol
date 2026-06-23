// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../../src/credentials/AgentCredentialEngine.sol";
import "../../src/interfaces/IAgentCredentialEngine.sol";

contract AgentCredentialEngineTest is Test {
    AgentCredentialEngine engine;

    bytes32 internal constant AGENT_ID = keccak256("agent-a");
    bytes32 internal constant AGENT_ID_2 = keccak256("agent-b");

    function setUp() public {
        engine = new AgentCredentialEngine();
    }

    function testAddCredential() public {
        engine.addCredential(AGENT_ID, "Solidity");

        IAgentCredentialEngine.Credential[] memory creds = engine.getCredentials(AGENT_ID);

        assertEq(creds.length, 1);
    }

    function testCredentialStoredCorrectly() public {
        engine.addCredential(AGENT_ID, "Solidity");

        IAgentCredentialEngine.Credential[] memory creds = engine.getCredentials(AGENT_ID);

        assertEq(creds[0].agentId, AGENT_ID);
        assertEq(creds[0].value, "Solidity");
    }

    function testIssuedTimestampSet() public {
        engine.addCredential(AGENT_ID, "Solidity");

        IAgentCredentialEngine.Credential[] memory creds = engine.getCredentials(AGENT_ID);

        assertEq(creds[0].issuedAt, block.timestamp);
    }

    function testHasCredentialReturnsTrue() public {
        string memory credential = "Solidity";

        engine.addCredential(AGENT_ID, credential);

        bool exists = engine.hasCredential(AGENT_ID, keccak256(bytes(credential)));

        assertTrue(exists);
    }

    function testUnknownCredentialReturnsFalse() public view {
        bool exists = engine.hasCredential(AGENT_ID, keccak256(bytes("Unknown")));

        assertFalse(exists);
    }

    function testMultipleCredentialsAccumulate() public {
        engine.addCredential(AGENT_ID, "Solidity");
        engine.addCredential(AGENT_ID, "Rust");
        engine.addCredential(AGENT_ID, "AI");

        IAgentCredentialEngine.Credential[] memory creds = engine.getCredentials(AGENT_ID);

        assertEq(creds.length, 3);
    }

    function testDifferentAgentsHaveSeparateCredentials() public {
        engine.addCredential(AGENT_ID, "Solidity");
        engine.addCredential(AGENT_ID_2, "Rust");

        IAgentCredentialEngine.Credential[] memory credsA = engine.getCredentials(AGENT_ID);

        IAgentCredentialEngine.Credential[] memory credsB = engine.getCredentials(AGENT_ID_2);

        assertEq(credsA.length, 1);
        assertEq(credsB.length, 1);

        assertEq(credsA[0].value, "Solidity");
        assertEq(credsB[0].value, "Rust");
    }

    function testCannotAddEmptyCredential() public {
        vm.expectRevert(AgentCredentialEngine.EmptyCredential.selector);

        engine.addCredential(AGENT_ID, "");
    }
}
