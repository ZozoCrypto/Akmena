from eth_abi import encode
from eth_account import Account
from eth_account.messages import encode_typed_data
from eth_utils import keccak, to_checksum_address


PRIVATE_KEY = bytes.fromhex(
    "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
)

EXPECTED_AGENT = "0x8fd379246834eac74B8419FfdA202CF8051F7A03"

EXPECTED_TYPE_HASH = (
    "0x434d4081110346a715fea42f2b6438b5774f9115417f52d641645515b2e02dbc"
)

EXPECTED_STRUCT_HASH = (
    "0x73ec1716f6ed03db3c27f1cfe7cbba6da82257cf14dc14703773e03f1e3e39a0"
)

EXPECTED_DOMAIN_SEPARATOR = (
    "0xe72b17187748ed28d0af4802bef0e21f624f3ea9ba325851c9e2e4e0147e732e"
)

EXPECTED_DIGEST = (
    "0xf5eb29d98d44669c00d34e952736e76a27654923a7f3ea4a56d5c484329d053a"
)


def build_vector():
    account = Account.from_key(PRIVATE_KEY)

    operator = to_checksum_address(
        "0x0000000000000000000000000000000000001111"
    )

    agent = account.address

    target = to_checksum_address(
        "0x0000000000000000000000000000000000002222"
    )

    selector = bytes.fromhex("fe0d94c1")

    payload = bytes.fromhex(
        "fe0d94c1"
        "000000000000000000000000000000000000000000000000"
        "0de0b6b3a7640000"
    )

    calldata_hash = keccak(payload)

    proof_module_key = keccak(
        text="PRODUCTION_PROOF"
    )

    asset = to_checksum_address("0x0000000000000000000000000000000000000000")
    amount = 10**18


    value = 0
    proof_id = 0
    nonce = 12345
    valid_after = 1
    deadline = 3600

    type_string = (
        "ExecutionIntent("
        "address operator,"
        "address agent,"
        "address target,"
        "bytes4 selector,"
        "bytes32 calldataHash,"
        "address asset,"
"uint256 amount,"
        "uint256 value,"
        "bytes32 proofModuleKey,"
        "uint256 proofId,"
        "uint256 nonce,"
        "uint256 validAfter,"
        "uint256 deadline"
        ")"
    )

    type_hash = keccak(text=type_string)

    struct_hash = keccak(
        encode(
            [
                "bytes32",
                "address",
                "address",
                "address",
                "bytes4",
                "bytes32",
            "address",
                "uint256",
                "uint256",
                "bytes32",
                "uint256",
                "uint256",
                "uint256",
                "uint256",
            ],
            [
                type_hash,
                operator,
                agent,
                target,
                selector,
                calldata_hash,
                    asset,
                amount,
                value,
                proof_module_key,
                proof_id,
                nonce,
                valid_after,
                deadline,
            ],
        )
    )

    domain = {
        "name": "AkmenaExecutionAuthorization",
        "version": "2",
        "chainId": 31337,
        "verifyingContract": to_checksum_address(
            "0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f"
        ),
    }

    message_types = {
        "ExecutionIntent": [
            {"name": "operator", "type": "address"},
            {"name": "agent", "type": "address"},
            {"name": "target", "type": "address"},
            {"name": "selector", "type": "bytes4"},
            {"name": "calldataHash", "type": "bytes32"},
            {"name": "asset", "type": "address"},
            {"name": "amount", "type": "uint256"},
            {"name": "value", "type": "uint256"},
            {"name": "proofModuleKey", "type": "bytes32"},
            {"name": "proofId", "type": "uint256"},
            {"name": "nonce", "type": "uint256"},
            {"name": "validAfter", "type": "uint256"},
            {"name": "deadline", "type": "uint256"},
        ]
    }

    message = {
        "operator": operator,
        "agent": agent,
        "target": target,
        "selector": selector,
        "calldataHash": calldata_hash,
        "asset": asset,
        "amount": amount,
        "value": value,
        "proofModuleKey": proof_module_key,
        "proofId": proof_id,
        "nonce": nonce,
        "validAfter": valid_after,
        "deadline": deadline,
    }

    signable = encode_typed_data(
        domain_data=domain,
        message_types=message_types,
        message_data=message,
    )

    signed = Account.sign_message(
        signable,
        PRIVATE_KEY,
    )

    recovered = Account.recover_message(
        signable,
        signature=signed.signature,
    )

    return {
        "type_hash": "0x" + type_hash.hex(),
        "struct_hash": "0x" + struct_hash.hex(),
        "domain_separator": "0x" + signable.header.hex(),
        "digest": "0x" + signed.message_hash.hex(),
        "recovered": recovered,
    }


def test_eip712_components_match_production_vector():
    vector = build_vector()

    assert vector["type_hash"] == EXPECTED_TYPE_HASH
    assert vector["struct_hash"] == EXPECTED_STRUCT_HASH
    assert vector["domain_separator"] == EXPECTED_DOMAIN_SEPARATOR
    assert vector["digest"] == EXPECTED_DIGEST
    assert vector["recovered"] == EXPECTED_AGENT


def test_eip712_digest_is_stable():
    first = build_vector()
    second = build_vector()

    assert first == second
