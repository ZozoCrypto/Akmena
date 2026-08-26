from dataclasses import dataclass
from typing import Any, Dict, Optional

from eth_account import Account
from eth_account.messages import encode_typed_data
from eth_utils import keccak


EXECUTION_INTENT_TYPE = (
    "ExecutionIntent("
    "address operator,"
    "address agent,"
    "address target,"
    "bytes4 selector,"
    "bytes32 calldataHash,"
    "uint256 amount,"
    "uint256 value,"
    "bytes32 proofModuleKey,"
    "uint256 proofId,"
    "uint256 nonce,"
    "uint256 validAfter,"
    "uint256 deadline"
    ")"
)


@dataclass(frozen=True)
class ExecutionIntent:
    """
    Exact Python representation of the production
    AkmenaExecutionAuthorization.ExecutionIntent.

    Field order MUST NOT change.
    """

    operator: str
    agent: str
    target: str
    selector: bytes
    calldata_hash: bytes
    amount: int
    value: int
    proof_module_key: bytes
    proof_id: int
    nonce: int
    valid_after: int
    deadline: int

    def as_contract_tuple(self) -> tuple:
        """
        Return the exact tuple expected by the Solidity ABI.
        """
        return (
            self.operator,
            self.agent,
            self.target,
            self.selector,
            self.calldata_hash,
            self.amount,
            self.value,
            self.proof_module_key,
            self.proof_id,
            self.nonce,
            self.valid_after,
            self.deadline,
        )


class AuthorizationModule:
    """
    Python client for AkmenaExecutionAuthorization.

    This module owns:
      - execution-intent construction
      - calldata hashing
      - EIP-712 signing
      - digest calculation
      - signature recovery
      - authorization transaction construction

    It deliberately does NOT implement policy accounting.
    """

    def __init__(self, client, authorization_address: str, abi: list):
        self.client = client

        self.authorization_address = (
            self.client.w3.to_checksum_address(
                authorization_address
            )
        )

        self.contract = self.client.w3.eth.contract(
            address=self.authorization_address,
            abi=abi,
        )

    @staticmethod
    def execution_intent_type_hash() -> bytes:
        """
        Return the canonical Solidity ExecutionIntent type hash.
        """
        return keccak(text=EXECUTION_INTENT_TYPE)

    @staticmethod
    def selector_from_payload(payload: bytes) -> bytes:
        """
        Extract the first four calldata bytes.
        """
        if len(payload) < 4:
            raise ValueError(
                "Execution payload must contain at least 4 bytes."
            )

        return payload[:4]

    @staticmethod
    def calldata_hash(payload: bytes) -> bytes:
        """
        Hash the exact calldata that will execute.
        """
        return keccak(payload)

    def build_intent(
        self,
        *,
        operator: str,
        agent: str,
        target: str,
        payload: bytes,
        amount: int,
        value: int,
        proof_module_key: bytes,
        proof_id: int,
        nonce: int,
        valid_after: int,
        deadline: int,
    ) -> ExecutionIntent:
        """
        Construct an ExecutionIntent from the exact execution payload.

        selector and calldata_hash are derived from payload.
        They are never independently supplied by the caller.
        """

        if not isinstance(payload, bytes):
            raise TypeError("payload must be bytes")

        if len(payload) < 4:
            raise ValueError(
                "Execution payload must contain at least 4 bytes."
            )

        operator = self.client.w3.to_checksum_address(operator)
        agent = self.client.w3.to_checksum_address(agent)
        target = self.client.w3.to_checksum_address(target)

        selector = self.selector_from_payload(payload)
        calldata_hash = self.calldata_hash(payload)

        return ExecutionIntent(
            operator=operator,
            agent=agent,
            target=target,
            selector=selector,
            calldata_hash=calldata_hash,
            amount=amount,
            value=value,
            proof_module_key=proof_module_key,
            proof_id=proof_id,
            nonce=nonce,
            valid_after=valid_after,
            deadline=deadline,
        )

    def _typed_data(
        self,
        intent: ExecutionIntent,
        chain_id: int,
    ) -> Dict[str, Any]:
        """
        Build the exact EIP-712 typed-data object used by Solidity.
        """

        domain = {
            "name": "AkmenaExecutionAuthorization",
            "version": "1",
            "chainId": chain_id,
            "verifyingContract": self.authorization_address,
        }

        types = {
            "ExecutionIntent": [
                {
                    "name": "operator",
                    "type": "address",
                },
                {
                    "name": "agent",
                    "type": "address",
                },
                {
                    "name": "target",
                    "type": "address",
                },
                {
                    "name": "selector",
                    "type": "bytes4",
                },
                {
                    "name": "calldataHash",
                    "type": "bytes32",
                },
                {
                    "name": "amount",
                    "type": "uint256",
                },
                {
                    "name": "value",
                    "type": "uint256",
                },
                {
                    "name": "proofModuleKey",
                    "type": "bytes32",
                },
                {
                    "name": "proofId",
                    "type": "uint256",
                },
                {
                    "name": "nonce",
                    "type": "uint256",
                },
                {
                    "name": "validAfter",
                    "type": "uint256",
                },
                {
                    "name": "deadline",
                    "type": "uint256",
                },
            ]
        }

        message = {
            "operator": intent.operator,
            "agent": intent.agent,
            "target": intent.target,
            "selector": intent.selector,
            "calldataHash": intent.calldata_hash,
            "amount": intent.amount,
            "value": intent.value,
            "proofModuleKey": intent.proof_module_key,
            "proofId": intent.proof_id,
            "nonce": intent.nonce,
            "validAfter": intent.valid_after,
            "deadline": intent.deadline,
        }

        return {
            "types": types,
            "domain": domain,
            "primaryType": "ExecutionIntent",
            "message": message,
        }

    def sign_intent(
        self,
        intent: ExecutionIntent,
        private_key: str,
        *,
        chain_id: Optional[int] = None,
    ) -> bytes:
        """
        Sign an ExecutionIntent using the production EIP-712 domain.
        """

        if chain_id is None:
            chain_id = self.client.w3.eth.chain_id

        typed_data = self._typed_data(
            intent,
            chain_id,
        )

        signable = encode_typed_data(
            full_message=typed_data,
        )

        signed = Account.sign_message(
            signable,
            private_key,
        )

        return signed.signature

    def hash_intent(
        self,
        intent: ExecutionIntent,
    ) -> bytes:
        """
        Ask the production authorization contract for its digest.

        This is the strongest available SDK-side verification because
        the Solidity contract remains authoritative.
        """

        return self.contract.functions.hashIntent(
            intent.as_contract_tuple()
        ).call()

    def build_verify_and_consume_call(
        self,
        intent: ExecutionIntent,
        payload: bytes,
        signature: bytes,
        *,
        tx_value: Optional[int] = None,
    ) -> dict:
        """
        Build the production verifyAndConsume transaction.

        actualValue defaults to intent.value and can only be overridden
        explicitly when constructing a deliberate boundary test.
        """

        if tx_value is None:
            tx_value = intent.value

        if tx_value != intent.value:
            raise ValueError(
                "tx_value must equal intent.value for a normal "
                "authorized execution."
            )

        return self.contract.functions.verifyAndConsume(
            intent.as_contract_tuple(),
            payload,
            tx_value,
            signature,
        ).build_transaction(
            {
                "from": self.client.get_agent_address(),
                "value": tx_value,
                "nonce": self.client.w3.eth.get_transaction_count(
                    self.client.get_agent_address()
                ),
            }
        )

    def used_nonce(
        self,
        agent: str,
        nonce: int,
    ) -> bool:
        """
        Query production nonce consumption state.
        """

        agent = self.client.w3.to_checksum_address(agent)

        return self.contract.functions.usedNonces(
            agent,
            nonce,
        ).call()
