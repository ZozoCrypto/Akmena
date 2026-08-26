from eth_account import Account
from eth_utils import keccak

from akmena.modules.authorization import (
    AuthorizationModule,
    ExecutionIntent,
)


PRIVATE_KEY = (
    "0x"
    + "aa" * 32
)

AGENT = Account.from_key(PRIVATE_KEY).address

OPERATOR = "0x0000000000000000000000000000000000001111"
TARGET = "0x0000000000000000000000000000000000002222"

PAYLOAD = bytes.fromhex(
    "fe0d94c1"
    "000000000000000000000000000000000000000000000000"
    "0de0b6b3a7640000"
)

PROOF_MODULE_KEY = keccak(
    text="PRODUCTION_PROOF"
)


class DummyW3:
    pass


def make_module():
    module = object.__new__(AuthorizationModule)

    module.client = None
    module.authorization_address = (
        "0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f"
    )

    return module


def test_execution_intent_type_hash_matches_production():
    module = make_module()

    assert (
        "0x"
        + module.execution_intent_type_hash().hex()
        ==
        "0xfbad3ac99ebab7a8672aada196f2f59ef0336807b51f80bc0e51757f78002dc8"
    )


def test_payload_derives_selector_and_calldata_hash():
    module = make_module()

    selector = module.selector_from_payload(PAYLOAD)
    calldata_hash = module.calldata_hash(PAYLOAD)

    assert selector == bytes.fromhex("fe0d94c1")
    assert calldata_hash == keccak(PAYLOAD)


def test_build_intent_contains_exact_execution_binding():
    module = make_module()

    class DummyClient:
        class DummyW3:
            @staticmethod
            def to_checksum_address(value):
                from eth_utils import to_checksum_address
                return to_checksum_address(value)

        w3 = DummyW3()

    module.client = DummyClient()

    intent = module.build_intent(
        operator=OPERATOR,
        agent=AGENT,
        target=TARGET,
        payload=PAYLOAD,
        amount=10**18,
        value=0,
        proof_module_key=PROOF_MODULE_KEY,
        proof_id=0,
        nonce=12345,
        valid_after=1,
        deadline=3600,
    )

    assert intent.operator == OPERATOR
    assert intent.agent == AGENT
    assert intent.target == TARGET
    assert intent.selector == bytes.fromhex("fe0d94c1")
    assert intent.calldata_hash == keccak(PAYLOAD)
    assert intent.amount == 10**18
    assert intent.value == 0
    assert intent.proof_module_key == PROOF_MODULE_KEY
    assert intent.proof_id == 0
    assert intent.nonce == 12345
    assert intent.valid_after == 1
    assert intent.deadline == 3600


def test_intent_tuple_matches_solidity_field_order():
    intent = ExecutionIntent(
        operator=OPERATOR,
        agent=AGENT,
        target=TARGET,
        selector=bytes.fromhex("fe0d94c1"),
        calldata_hash=keccak(PAYLOAD),
        amount=10**18,
        value=0,
        proof_module_key=PROOF_MODULE_KEY,
        proof_id=0,
        nonce=12345,
        valid_after=1,
        deadline=3600,
    )

    values = intent.as_contract_tuple()

    assert len(values) == 12

    assert values[0] == OPERATOR
    assert values[1] == AGENT
    assert values[2] == TARGET
    assert values[3] == bytes.fromhex("fe0d94c1")
    assert values[4] == keccak(PAYLOAD)
    assert values[5] == 10**18
    assert values[6] == 0
    assert values[7] == PROOF_MODULE_KEY
    assert values[8] == 0
    assert values[9] == 12345
    assert values[10] == 1
    assert values[11] == 3600


def test_signing_recovers_expected_agent():
    module = make_module()

    class DummyClient:
        class DummyW3:
            @staticmethod
            def to_checksum_address(value):
                from eth_utils import to_checksum_address
                return to_checksum_address(value)

        w3 = DummyW3()

    module.client = DummyClient()

    intent = module.build_intent(
        operator=OPERATOR,
        agent=AGENT,
        target=TARGET,
        payload=PAYLOAD,
        amount=10**18,
        value=0,
        proof_module_key=PROOF_MODULE_KEY,
        proof_id=0,
        nonce=12345,
        valid_after=1,
        deadline=3600,
    )

    signature = module.sign_intent(
        intent,
        PRIVATE_KEY,
        chain_id=31337,
    )

    assert len(signature) == 65

    from eth_account.messages import encode_typed_data

    typed_data = module._typed_data(
        intent,
        31337,
    )

    signable = encode_typed_data(
        full_message=typed_data,
    )

    recovered = Account.recover_message(
        signable,
        signature=signature,
    )

    assert recovered == AGENT
