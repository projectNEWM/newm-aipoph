from ecdsa import Ed25519, SigningKey

sk = SigningKey.generate(curve=Ed25519)

vk = sk.verifying_key
print(vk.to_string().hex())

msg = "398c36e82ee7a6d7a2bee6fde26fc0c9df373f687b9ec73b5968f9fae8ff92de"
msg = bytes.fromhex(msg)
print(msg.hex())

signature = sk.sign(msg)
print(signature.hex())

print(vk.verify(signature, msg))
