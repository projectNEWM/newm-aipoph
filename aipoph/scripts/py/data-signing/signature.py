from ecdsa import Ed25519, SigningKey, VerifyingKey

# sk = SigningKey.generate(curve=Ed25519)
# sk_string = sk.to_string()
# print(sk_string.hex())


def verify(key_path: str, signature: str, msg: str) -> bool:
    with open(key_path, 'r') as file:
        vkey = file.readline().rstrip()
    vk_string = bytes.fromhex(vkey)
    vk = VerifyingKey.from_string(vk_string, curve=Ed25519)
    signature = bytes.fromhex(signature)
    msg = bytes.fromhex(msg)
    return vk.verify(signature, msg)


def sign(key_path: str, msg: str) -> str:
    with open(key_path, 'r') as file:
        skey = file.readline().rstrip()
    sk_string = bytes.fromhex(skey)
    sk = SigningKey.from_string(sk_string, curve=Ed25519)
    msg = bytes.fromhex(msg)
    signature = sk.sign(msg)
    return signature.hex()


if __name__ == "__main__":
    msg = "398c36e82ee7a6d7a2bee6fde26fc0c9df373f687b9ec73b5968f9fae8ff92de"
    skey_path = "../../wallets/website-wallet/payment.skey"
    vkey_path = "../../wallets/website-wallet/payment.vkey"
    signature = sign(skey_path, msg)
    outcome = verify(vkey_path, signature, msg)
    print(outcome)
