import hashlib

import cbor2


def compute_blake2b_256_hex(data_hex):
    """
    Computes the BLAKE2b 256-bit (32-byte) hash of the given hexadecimal data.

    :param data_hex: The hexadecimal string representation of the data to hash.
    :return: The hexadecimal representation of the BLAKE2b 256-bit hash.
    """
    # Convert the hexadecimal string to bytes
    data_bytes = bytes.fromhex(data_hex)

    # Create a BLAKE2b hash object with a digest size of 32 bytes for BLAKE2b 256-bit
    hasher = hashlib.blake2b(digest_size=32)

    # Update the hasher with the input data
    hasher.update(data_bytes)

    # Return the hexadecimal representation of the hash
    return hasher.hexdigest()


def coloring_hash(values):
    """
    Creates a CBOR byte string representing an indefinite-length array
    with the given values.

    :param values: A list of integer values to encode in the array.
    :return: A hexadecimal string representing the encoded CBOR data.
    """
    # Create a bytearray and start with the indefinite-length array prefix (0x9f)
    cbor_bytes = bytearray([0x9f])

    # Encode each value and append it to the array
    for value in values:
        cbor_bytes += cbor2.dumps(value)

    # End the array with the "break" code (0xff)
    cbor_bytes.append(0xff)

    # Convert the bytearray to a bytes object
    graph_cbor = bytes(cbor_bytes)

    return graph_cbor.hex()


def graph_hash(edges):
    # Start with the indefinite array prefix
    encoded = bytearray([0x9f])

    # Encode each element with tag 121 and as an indefinite length array
    for element in edges:
        # Tag 121 prefix
        encoded += bytearray([0xd8, 0x79])
        # Start of an indefinite-length array
        encoded += bytearray([0x9f])
        # Encoded edges
        for item in element:
            encoded += cbor2.dumps(item)
        # End of this inner array
        encoded += bytearray([0xff])

    # End of the outer array
    encoded += bytearray([0xff])

    return bytes(encoded)


# Define the edges to encode
graph = [
    [2, 1], [1, 0], [0, 4], [4, 3], [3, 1], [2, 0], [4, 2]
]
# Encode the data
graph_cbor = graph_hash(graph)

colors = [0, 1, 2, 0, 1]

color_cbor = coloring_hash(colors)

# Display the CBOR data in hexadecimal format
hex_cbor = graph_cbor.hex()

# Using a digest size of 32 bytes for example
hash_result = compute_blake2b_256_hex(hex_cbor)
print(f"BLAKE2b hash of '{hex_cbor}' (32-byte digest): {hash_result}")
print(hash_result == "b3064a26269668c85c14d735a77b3b225f5e30ad911870428d3d8daba85e486c")

hash_result = compute_blake2b_256_hex(color_cbor)
print(f"BLAKE2b hash of '{color_cbor}' (32-byte digest): {hash_result}")

print(hash_result == "398c36e82ee7a6d7a2bee6fde26fc0c9df373f687b9ec73b5968f9fae8ff92de")
