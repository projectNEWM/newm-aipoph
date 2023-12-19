import binascii
import hashlib


def token_name(txHash, index, prefix):
    txBytes = binascii.unhexlify(txHash)
    h = hashlib.new('sha3_256')
    h.update(txBytes)
    txHash = h.hexdigest()
    x = hex(index)[-2:]
    if "x" in x:
        x = x.replace("x", "0")
    txHash = prefix + x + txHash
    print(txHash[0:64])
    return txHash[0:64]
